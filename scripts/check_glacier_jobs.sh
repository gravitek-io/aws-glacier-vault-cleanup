#!/usr/bin/env bash
set -euo pipefail

# Determine project root directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
DATA_DIR="$ROOT_DIR/data"

ACCOUNT_ID="-"               # Your account ID (or "-")
REGION="eu-west-1"           # Adapt to your region
JOBS_DIR="$DATA_DIR/job_data"

echo "🔍 Checking inventory jobs status"
echo "========================================================"

TOTAL_JOBS=0
COMPLETED_JOBS=0
IN_PROGRESS_JOBS=0
FAILED_JOBS=0

for JOB_FILE in "$JOBS_DIR"/job*.json; do
  [[ -f "$JOB_FILE" ]] || continue

  TOTAL_JOBS=$((TOTAL_JOBS + 1))

  VAULT=$(jq -r '.location' "$JOB_FILE" | sed -E 's#.*/vaults/([^/]+)/.*#\1#')
  JOB_ID=$(jq -r '.jobId' "$JOB_FILE")

  if [[ -z "$VAULT" || -z "$JOB_ID" || "$VAULT" == "null" ]]; then
    echo "⚠️  Cannot extract vault/jobId from $JOB_FILE"
    continue
  fi

  echo ""
  echo "📦 Vault : $VAULT"
  echo "   Job ID : $JOB_ID"

  # Get job status
  JOB_STATUS=$(aws glacier describe-job \
    --account-id="$ACCOUNT_ID" \
    --vault-name="$VAULT" \
    --job-id="$JOB_ID" \
    --region="$REGION" \
    --no-cli-pager)

  COMPLETED=$(echo "$JOB_STATUS" | jq -r '.Completed')
  STATUS_CODE=$(echo "$JOB_STATUS" | jq -r '.StatusCode')
  STATUS_MESSAGE=$(echo "$JOB_STATUS" | jq -r '.StatusMessage // "N/A"')

  if [[ "$COMPLETED" == "true" ]]; then
    if [[ "$STATUS_CODE" == "Succeeded" ]]; then
      echo "   ✅ Status: Completed successfully"
      COMPLETED_JOBS=$((COMPLETED_JOBS + 1))
    else
      echo "   ❌ Status: Completed with error ($STATUS_CODE)"
      echo "   Message: $STATUS_MESSAGE"
      FAILED_JOBS=$((FAILED_JOBS + 1))
    fi
  else
    echo "   ⏳ Status: In Progress ($STATUS_CODE)"
    echo "   Message: $STATUS_MESSAGE"
    IN_PROGRESS_JOBS=$((IN_PROGRESS_JOBS + 1))
  fi
done

echo ""
echo "=============================="
echo "📊 SUMMARY"
echo "=============================="
echo "Total jobs: $TOTAL_JOBS"
echo "✅ Completed: $COMPLETED_JOBS"
echo "⏳ In Progress : $IN_PROGRESS_JOBS"
echo "❌ Failed: $FAILED_JOBS"
echo ""

if [[ $COMPLETED_JOBS -eq $TOTAL_JOBS ]] && [[ $TOTAL_JOBS -gt 0 ]]; then
  echo "🎉 All jobs are completed!"
  echo "   You can now run: ./delete_glacier_auto.sh"
elif [[ $IN_PROGRESS_JOBS -gt 0 ]]; then
  echo "⏳ Some jobs are still running. Please wait."
  echo "   Inventory jobs usually take 3-5 hours."
else
  echo "⚠️  Check failed jobs before continuing."
fi
