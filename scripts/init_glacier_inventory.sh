#!/usr/bin/env bash
set -euo pipefail

# Determine project root directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
DATA_DIR="$ROOT_DIR/data"

ACCOUNT_ID="-"               # Your account ID (or "-")
REGION="eu-west-1"           # Adapt to your region
GLACIER_JSON="$DATA_DIR/glacier.json"
JOBS_DIR="$DATA_DIR"

echo "🚀 Initialization of Glacier inventory jobs"
echo "================================================"

# Check that glacier.json exists
if [[ ! -f "$GLACIER_JSON" ]]; then
  echo "❌ File .* not found"
  exit 1
fi

# Extract vault list
VAULTS=$(jq -r '.VaultList[].VaultName' "$GLACIER_JSON")

if [[ -z "$VAULTS" ]]; then
  echo "❌ No vaults found in $GLACIER_JSON"
  exit 1
fi

echo "📋 Vaults found:"
echo "$VAULTS" | sed 's/^/  - /'
echo ""

# For each vault, start a job inventory
for VAULT in $VAULTS; do
  echo "=============================="
  echo "📦 Vault : $VAULT"

  # Lancer le job inventory
  echo "🔄 Launching job inventory..."
  JOB_OUTPUT=$(aws glacier initiate-job \
    --account-id "$ACCOUNT_ID" \
    --vault-name "$VAULT" \
    --region "$REGION" \
    --job-parameters '{"Type":"inventory-retrieval"}')

  # Extract job ID and location
  JOB_ID=$(echo "$JOB_OUTPUT" | jq -r '.jobId')
  LOCATION=$(echo "$JOB_OUTPUT" | jq -r '.location')

  if [[ -z "$JOB_ID" || "$JOB_ID" == "null" ]]; then
    echo "❌ Failed to launch job for $VAULT"
    continue
  fi

  echo "✅ Job launched successfully"
  echo "   Job ID : $JOB_ID"
  echo "   Location : $LOCATION"

  # Save job to a file job_<vault>.json
  JOB_FILE="$JOBS_DIR/job_${VAULT}.json"
  echo "$JOB_OUTPUT" > "$JOB_FILE"
  echo "💾 Job saved in: $JOB_FILE"

  echo ""
done

echo "🎉 All jobs d inventory have been launched!"
echo ""
echo "⏳ IMPORTANT : Glacier inventory jobs usually take 3-5 hours."
echo "   Use check_glacier_jobs.sh to check job status."
echo "   Once all jobs are completed, run delete_glacier_auto.sh to clean up."
