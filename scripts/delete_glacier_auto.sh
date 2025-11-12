#!/usr/bin/env bash
set -euo pipefail

# Determine project root directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
DATA_DIR="$ROOT_DIR/data"

ACCOUNT_ID="-"               # Ton ID de compte (ou "-")
REGION="eu-west-1"           # Adapte selon ta région
JOBS_DIR="$DATA_DIR/job_data"         # Folder containing job*.json
TMP_DIR="$DATA_DIR/glacier_inventory"
LOG_DIR="$DATA_DIR/glacier_logs"
DELAY_BETWEEN_DELETES=0.2    # Delay in seconds to avoid rate limiting (currently disabled)
MAX_RETRIES=3                # Number of retries in case of error (increased for network issues)
RETRY_DELAY=2                # Initial delay in seconds between retries (exponential backoff)

mkdir -p "$TMP_DIR" "$LOG_DIR"

# Initialize log file with timestamp
LOG_FILE="$LOG_DIR/deletion_$(date +%Y%m%d_%H%M%S).log"

# Logging function
log() {
  local level="$1"
  shift
  local message="$@"
  local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
  echo "[$timestamp] [$level] $message" | tee -a "$LOG_FILE"
}

# Check network connectivity
check_network() {
  local max_attempts=3
  local attempt=1

  while [[ $attempt -le $max_attempts ]]; do
    if curl -s --max-time 5 "https://glacier.${REGION}.amazonaws.com" > /dev/null 2>&1; then
      return 0
    fi
    log "WARN" "Network check failed (attempt $attempt/$max_attempts)"
    sleep 2
    attempt=$((attempt + 1))
  done

  log "ERROR" "Network connectivity lost after $max_attempts attempts"
  return 1
}

# Function to handle clean interruption (Ctrl+C)
cleanup_on_exit() {
  log "WARN" "Script interrupted by user (Ctrl+C)"
  log "INFO" "Progress has been saved. Rerun the script to resume."
  exit 130
}

trap cleanup_on_exit SIGINT SIGTERM

# Detect if running on macOS and caffeinate is available
USE_CAFFEINATE=false
if [[ "$(uname)" == "Darwin" ]] && command -v caffeinate &> /dev/null; then
  USE_CAFFEINATE=true
fi

# Self-restart with caffeinate if not already running under it
if [[ "$USE_CAFFEINATE" == true ]] && [[ -z "${CAFFEINATED:-}" ]]; then
  log "INFO" "Restarting with caffeinate to prevent system sleep..."
  echo "☕ Preventing system sleep with caffeinate..."
  export CAFFEINATED=1
  exec caffeinate -i "$0" "$@"
fi

log "INFO" "=== Starting Glacier deletion script ==="
log "INFO" "Log file: $LOG_FILE"
[[ -n "${CAFFEINATED:-}" ]] && log "INFO" "Running with caffeinate (sleep prevention enabled)"

DRY_RUN=false
VAULTS_ONLY=false

# Parse les arguments
for arg in "$@"; do
  case $arg in
    --dry-run)
      DRY_RUN=true
      log "INFO" "DRY RUN MODE enabled"
      echo "🔎 DRY RUN MODE enabled : no real deletion will be done"
      ;;
    --vaults-only)
      VAULTS_ONLY=true
      log "INFO" "VAULTS ONLY MODE enabled"
      echo "🗑️  MODE VAULTS ONLY : only delete empty vaults"
      ;;
    *)
      log "ERROR" "Unknown argument: $arg"
      echo "❌ Unknown argument: $arg"
      echo "Usage: $0 [--dry-run] [--vaults-only]"
      exit 1
      ;;
  esac
done

log "INFO" "Searching for job*.json files in $JOBS_DIR..."
echo "🔍 Searching for job*.json files in $JOBS_DIR..."
TOTAL_VAULTS=0
VAULTS_DELETED=0
VAULTS_FAILED=0

for JOB_FILE in "$JOBS_DIR"/job*.json; do
  [[ -f "$JOB_FILE" ]] || continue

  TOTAL_VAULTS=$((TOTAL_VAULTS + 1))
  echo ""
  echo "=============================="
  echo "📄 File: $JOB_FILE"

  VAULT=$(jq -r '.location' "$JOB_FILE" | sed -E 's#.*/vaults/([^/]+)/.*#\1#')
  JOB_ID=$(jq -r '.jobId' "$JOB_FILE")

  if [[ -z "$VAULT" || -z "$JOB_ID" || "$VAULT" == "null" ]]; then
    log "ERROR" "Cannot extract vault/jobId from $JOB_FILE"
    echo "⚠️  Cannot extract vault/jobId from $JOB_FILE"
    VAULTS_FAILED=$((VAULTS_FAILED + 1))
    continue
  fi

  log "INFO" "Processing vault: $VAULT (Job ID: $JOB_ID)"
  echo "➡️  Vault : $VAULT"
  echo "➡️  Job ID : $JOB_ID"

  INVENTORY_FILE="$TMP_DIR/inventory_${VAULT}.json"
  WORKING_INVENTORY="$TMP_DIR/inventory_${VAULT}.working.json"
  PROGRESS_FILE="$TMP_DIR/.progress_${VAULT}"

  # Vérifier le statut du job avant de télécharger
  if [[ ! -f "$INVENTORY_FILE" ]] && [[ "$VAULTS_ONLY" == false ]]; then
    echo "🔍 Vérification du statut du job..."
    JOB_STATUS=$(aws glacier describe-job \
      --account-id="$ACCOUNT_ID" \
      --vault-name="$VAULT" \
      --job-id="$JOB_ID" \
      --region="$REGION")

    COMPLETED=$(echo "$JOB_STATUS" | jq -r '.Completed')
    STATUS_CODE=$(echo "$JOB_STATUS" | jq -r '.StatusCode')

    if [[ "$COMPLETED" != "true" ]] || [[ "$STATUS_CODE" != "Succeeded" ]]; then
      echo "❌ Job not completed (Status: $STATUS_CODE)"
      echo "   Run ./check_glacier_jobs.sh to check status"
      VAULTS_FAILED=$((VAULTS_FAILED + 1))
      continue
    fi
    echo "✅ Job completed successfully"
  fi

  # Télécharger l'inventaire si nécessaire
  if [[ ! -f "$INVENTORY_FILE" ]] && [[ "$VAULTS_ONLY" == false ]]; then
    echo "📥 Downloading inventory..."
    if aws glacier get-job-output \
      --account-id="$ACCOUNT_ID" \
      --vault-name="$VAULT" \
      --job-id="$JOB_ID" \
      "$INVENTORY_FILE" \
      --region="$REGION"; then
      echo "✅ Inventory saved: $INVENTORY_FILE"
    else
      echo "❌ Failed to download inventory"
      VAULTS_FAILED=$((VAULTS_FAILED + 1))
      continue
    fi
  fi

  # Process archives (except in --vaults-only mode)
  if [[ "$VAULTS_ONLY" == false ]]; then
    # Vérifier si une copie de travail existe (reprise après interruption)
    if [[ -f "$WORKING_INVENTORY" ]]; then
      log "INFO" "Resume detected: using working copy for $VAULT"
      echo "🔄 Resume detected: using existing working inventory"
      ACTIVE_INVENTORY="$WORKING_INVENTORY"
    elif [[ -f "$INVENTORY_FILE" ]]; then
      # Create working copy for the first time
      log "INFO" "Creating working copy for $VAULT"
      cp "$INVENTORY_FILE" "$WORKING_INVENTORY"
      ACTIVE_INVENTORY="$WORKING_INVENTORY"
    else
      log "ERROR" "No inventory found for $VAULT"
      echo "❌ No inventory found"
      VAULTS_FAILED=$((VAULTS_FAILED + 1))
      continue
    fi

    # Validate JSON and extract archives
    if ! jq empty "$ACTIVE_INVENTORY" 2>/dev/null; then
      log "ERROR" "Invalid JSON file: $ACTIVE_INVENTORY"
      echo "❌ Invalid JSON file: $ACTIVE_INVENTORY"
      VAULTS_FAILED=$((VAULTS_FAILED + 1))
      continue
    fi

    ARCHIVE_COUNT=$(jq -r '.ArchiveList | length' "$ACTIVE_INVENTORY" 2>/dev/null || echo "0")
    ORIGINAL_COUNT=$(jq -r '.ArchiveList | length' "$INVENTORY_FILE" 2>/dev/null || echo "$ARCHIVE_COUNT")

    if [[ "$ARCHIVE_COUNT" -eq 0 ]]; then
      log "INFO" "No archives to delete in $VAULT"
      echo "⚠️  No archives found in $VAULT"
      # Clean working copy
      rm -f "$WORKING_INVENTORY" "$PROGRESS_FILE"
    else
      if [[ "$ARCHIVE_COUNT" -lt "$ORIGINAL_COUNT" ]]; then
        ALREADY_DELETED=$((ORIGINAL_COUNT - ARCHIVE_COUNT))
        log "INFO" "$ALREADY_DELETED/$ORIGINAL_COUNT archives already deleted in a previous run"
        echo "🔄 Resume: $ALREADY_DELETED/$ORIGINAL_COUNT archives already deleted"
      fi

      log "INFO" "$ARCHIVE_COUNT remaining archives in vault $VAULT"
      echo "🧨 $ARCHIVE_COUNT archives found in vault"

      if $DRY_RUN; then
        log "INFO" "DRY RUN : simulating deletion of $ARCHIVE_COUNT archives"
        echo "🚫 DRY RUN → suppression de $ARCHIVE_COUNT archives simulated"
      else
        echo "🧹 Real deletion of archives..."
        log "INFO" "Starting deletion of $ARCHIVE_COUNT archives"

        SUCCESS_COUNT=0
        FAILED_COUNT=0
        CURRENT=0
        START_TIME=$(date +%s)
        DELETED_IDS=()

        # Read all archive IDs into memory first (avoid race condition when updating file during read)
        log "INFO" "Loading archive IDs into memory..."
        mapfile -t ARCHIVE_IDS < <(jq -r '.ArchiveList[].ArchiveId' "$ACTIVE_INVENTORY")
        log "INFO" "Loaded ${#ARCHIVE_IDS[@]} archive IDs"

        for ID in "${ARCHIVE_IDS[@]}"; do
          CURRENT=$((CURRENT + 1))
          [[ -z "$ID" || "$ID" == "null" ]] && continue

          # Show progress every 25 archives
          if (( CURRENT % 25 == 0 )); then
            ELAPSED=$(($(date +%s) - START_TIME))
            RATE=$(echo "scale=2; $CURRENT / $ELAPSED" | bc 2>/dev/null || echo "?")
            REMAINING=$((ARCHIVE_COUNT - CURRENT))
            if [[ "$RATE" != "?" ]] && (( $(echo "$RATE > 0" | bc -l) )); then
              ETA=$(echo "scale=0; $REMAINING / $RATE / 60" | bc 2>/dev/null || echo "?")
              echo "   Progress: $CURRENT/$ARCHIVE_COUNT archives ($RATE/s, ETA: ${ETA}min)..."
              log "INFO" "Progress: $CURRENT/$ARCHIVE_COUNT archives processed"
            else
              echo "   Progress: $CURRENT/$ARCHIVE_COUNT archives processed..."
            fi
          fi

          # Retries with exponential backoff
          RETRY_COUNT=0
          SUCCESS=false

          while [[ $RETRY_COUNT -lt $MAX_RETRIES ]] && [[ "$SUCCESS" == false ]]; do
            ERROR_MSG=$(aws glacier delete-archive \
              --account-id="$ACCOUNT_ID" \
              --vault-name="$VAULT" \
              --region="$REGION" \
              --archive-id="$ID" 2>&1)
            EXIT_CODE=$?
            if [[ $EXIT_CODE -eq 0 ]]; then
              SUCCESS=true
              SUCCESS_COUNT=$((SUCCESS_COUNT + 1))

              # Add ID to batch deletion list
              DELETED_IDS+=("$ID")

              # Update JSON every 500 archives (for resume capability)
              if (( SUCCESS_COUNT % 500 == 0 )); then
                TEMP_JSON=$(mktemp)
                # Convert bash array to JSON array for jq
                DELETED_IDS_JSON=$(printf '%s\n' "${DELETED_IDS[@]}" | jq -R . | jq -s .)
                # Remove all deleted IDs at once
                jq --argjson ids "$DELETED_IDS_JSON" \
                  '.ArchiveList = [.ArchiveList[] | select(.ArchiveId as $id | $ids | index($id) | not)]' \
                  "$ACTIVE_INVENTORY" > "$TEMP_JSON"
                mv "$TEMP_JSON" "$ACTIVE_INVENTORY"
                echo "$SUCCESS_COUNT" > "$PROGRESS_FILE"
                DELETED_IDS=()
              fi
            else
              RETRY_COUNT=$((RETRY_COUNT + 1))
              if [[ $RETRY_COUNT -lt $MAX_RETRIES ]]; then
                # Check if it's a network error
                if echo "$ERROR_MSG" | grep -qiE "(connection|network|timeout|could not connect|endpoint)"; then
                  log "WARN" "Network error detected on archive ${ID:0:20}..., checking connectivity..."
                  echo "   ⚠️  Network error detected, checking connectivity..."
                  if ! check_network; then
                    log "ERROR" "Network connectivity lost, stopping script"
                    echo "   ❌ Network connectivity lost. Fix network and rerun script to resume."
                    exit 254
                  fi
                fi

                # Exponential backoff: 2s, 4s, 8s, etc.
                WAIT_TIME=$((RETRY_DELAY * (2 ** (RETRY_COUNT - 1))))
                log "WARN" "Error on archive ${ID:0:20}..., attempt $((RETRY_COUNT + 1))/$MAX_RETRIES (waiting ${WAIT_TIME}s): $ERROR_MSG"
                echo "   ⚠️  Error on archive ${ID:0:20}..., attempt $((RETRY_COUNT + 1))/$MAX_RETRIES (waiting ${WAIT_TIME}s)"
                echo "   Error: $ERROR_MSG"
                sleep "$WAIT_TIME"
              fi
            fi
          done

          if [[ "$SUCCESS" == false ]]; then
            log "ERROR" "Definitive deletion failure: ${ID:0:40} - Error: $ERROR_MSG"
            echo "   ❌ Definitive failure: ${ID:0:20}..."
            echo "   Error: $ERROR_MSG"
            FAILED_COUNT=$((FAILED_COUNT + 1))
          fi

          # Pause to avoid rate limiting
          #sleep "$DELAY_BETWEEN_DELETES"
        done

        # Update remaining IDs (last batch < 500)
        if (( ${#DELETED_IDS[@]} > 0 )); then
          TEMP_JSON=$(mktemp)
          # Convert bash array to JSON array for jq
          DELETED_IDS_JSON=$(printf '%s\n' "${DELETED_IDS[@]}" | jq -R . | jq -s .)
          # Remove all deleted IDs at once
          jq --argjson ids "$DELETED_IDS_JSON" \
            '.ArchiveList = [.ArchiveList[] | select(.ArchiveId as $id | $ids | index($id) | not)]' \
            "$ACTIVE_INVENTORY" > "$TEMP_JSON"
          mv "$TEMP_JSON" "$ACTIVE_INVENTORY"
          echo "$SUCCESS_COUNT" > "$PROGRESS_FILE"
        fi

        log "INFO" "Deletion completed for $VAULT : $SUCCESS_COUNT successful, $FAILED_COUNT failed"
        echo "✅ Deletion completed: $SUCCESS_COUNT successful, $FAILED_COUNT failed"

        if [[ $FAILED_COUNT -gt 0 ]]; then
          log "WARN" "Some archives could not be deleted in $VAULT"
          echo "⚠️  Some archives could not be deleted, vault cannot be deleted"
          echo "💡 You can rerun the script to retry only remaining archives"
          VAULTS_FAILED=$((VAULTS_FAILED + 1))
          continue
        else
          # All went well, cleaning progress files
          log "INFO" "All archives from .* have been successfully deleted"
          rm -f "$WORKING_INVENTORY" "$PROGRESS_FILE"
        fi
      fi
    fi
  fi

  # Vault deletion
  if $DRY_RUN; then
    log "INFO" "DRY RUN : simulating vault deletion $VAULT"
    echo "🚫 DRY RUN → suppression simulée du vault $VAULT"
    VAULTS_DELETED=$((VAULTS_DELETED + 1))
  else
    log "INFO" "Attempting to delete vault $VAULT"
    echo "🧹 Deleting empty vault: $VAULT"
    echo "   ⚠️  Note: Deletion may fail if vault was modified less than 24h ago"

    if aws glacier delete-vault \
      --account-id="$ACCOUNT_ID" \
      --vault-name="$VAULT" \
      --region="$REGION" 2>/dev/null; then
      log "INFO" "Vault successfully deleted: $VAULT"
      echo "✅ Vault deleted: $VAULT"
      VAULTS_DELETED=$((VAULTS_DELETED + 1))

      # Clean associated files
      rm -f "$INVENTORY_FILE" "$WORKING_INVENTORY" "$PROGRESS_FILE" "$JOBS_DIR/job_${VAULT}.json"
      log "INFO" "Temporary files cleaned for $VAULT"
    else
      log "ERROR" "Failed to delete vault $VAULT"
      echo "❌ Failed to delete vault $VAULT"
      echo "   Possible reasons:"
      echo "   - Vault still contains archives"
      echo "   - Vault was modified less than 24h ago"
      echo "   - Insufficient AWS permissions"
      echo ""
      echo "💡 To retry later: ./delete_glacier_auto.sh --vaults-only"
      VAULTS_FAILED=$((VAULTS_FAILED + 1))
    fi
  fi
done

echo ""
log "INFO" "=== Final summary ==="
echo "=============================="
echo "📊 FINAL SUMMARY"
echo "=============================="
echo "Total vaults processed: $TOTAL_VAULTS"
echo "✅ Vaults deleted: $VAULTS_DELETED"
echo "❌ Failures: $VAULTS_FAILED"
echo ""

log "INFO" "Total: $TOTAL_VAULTS vaults, Deleted: $VAULTS_DELETED, Failures: $VAULTS_FAILED"

if [[ $VAULTS_FAILED -gt 0 ]] && [[ "$DRY_RUN" == false ]]; then
  log "WARN" "Some vaults could not be deleted"
  echo "⚠️  Some vaults could not be deleted."
  echo "   Wait 24h then rerun: ./delete_glacier_auto.sh --vaults-only"
fi

log "INFO" "=== Script completed successfully ==="
log "INFO" "Full log available in: $LOG_FILE"
echo "🎉 Script completed."
echo ""
echo "📄 Full log: $LOG_FILE"

