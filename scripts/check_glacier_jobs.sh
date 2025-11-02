#!/usr/bin/env bash
set -euo pipefail

# Déterminer le répertoire racine du projet
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
DATA_DIR="$ROOT_DIR/data"

ACCOUNT_ID="-"               # Ton ID de compte (ou "-")
REGION="eu-west-1"           # Adapte selon ta région
JOBS_DIR="$DATA_DIR"

echo "🔍 Vérification de l'état des jobs d'inventaire Glacier"
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
    echo "⚠️  Impossible d'extraire vault/jobId depuis $JOB_FILE"
    continue
  fi

  echo ""
  echo "📦 Vault : $VAULT"
  echo "   Job ID : $JOB_ID"

  # Récupérer le statut du job
  JOB_STATUS=$(aws glacier describe-job \
    --account-id "$ACCOUNT_ID" \
    --vault-name "$VAULT" \
    --job-id "$JOB_ID" \
    --region "$REGION")

  COMPLETED=$(echo "$JOB_STATUS" | jq -r '.Completed')
  STATUS_CODE=$(echo "$JOB_STATUS" | jq -r '.StatusCode')
  STATUS_MESSAGE=$(echo "$JOB_STATUS" | jq -r '.StatusMessage // "N/A"')

  if [[ "$COMPLETED" == "true" ]]; then
    if [[ "$STATUS_CODE" == "Succeeded" ]]; then
      echo "   ✅ Statut : Terminé avec succès"
      COMPLETED_JOBS=$((COMPLETED_JOBS + 1))
    else
      echo "   ❌ Statut : Terminé avec erreur ($STATUS_CODE)"
      echo "   Message : $STATUS_MESSAGE"
      FAILED_JOBS=$((FAILED_JOBS + 1))
    fi
  else
    echo "   ⏳ Statut : En cours ($STATUS_CODE)"
    echo "   Message : $STATUS_MESSAGE"
    IN_PROGRESS_JOBS=$((IN_PROGRESS_JOBS + 1))
  fi
done

echo ""
echo "=============================="
echo "📊 RÉSUMÉ"
echo "=============================="
echo "Total de jobs : $TOTAL_JOBS"
echo "✅ Terminés : $COMPLETED_JOBS"
echo "⏳ En cours : $IN_PROGRESS_JOBS"
echo "❌ Échoués : $FAILED_JOBS"
echo ""

if [[ $COMPLETED_JOBS -eq $TOTAL_JOBS ]] && [[ $TOTAL_JOBS -gt 0 ]]; then
  echo "🎉 Tous les jobs sont terminés !"
  echo "   Vous pouvez maintenant exécuter : ./delete_glacier_auto.sh"
elif [[ $IN_PROGRESS_JOBS -gt 0 ]]; then
  echo "⏳ Certains jobs sont encore en cours. Veuillez patienter."
  echo "   Les jobs d'inventaire prennent généralement 3-5 heures."
else
  echo "⚠️  Vérifiez les jobs échoués avant de continuer."
fi
