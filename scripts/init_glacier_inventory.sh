#!/usr/bin/env bash
set -euo pipefail

# Déterminer le répertoire racine du projet
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
DATA_DIR="$ROOT_DIR/data"

ACCOUNT_ID="-"               # Ton ID de compte (ou "-")
REGION="eu-west-1"           # Adapte selon ta région
GLACIER_JSON="$DATA_DIR/glacier.json"
JOBS_DIR="$DATA_DIR"

echo "🚀 Initialisation des jobs d'inventaire Glacier"
echo "================================================"

# Vérifier que glacier.json existe
if [[ ! -f "$GLACIER_JSON" ]]; then
  echo "❌ Fichier $GLACIER_JSON introuvable"
  exit 1
fi

# Extraire la liste des vaults
VAULTS=$(jq -r '.VaultList[].VaultName' "$GLACIER_JSON")

if [[ -z "$VAULTS" ]]; then
  echo "❌ Aucun vault trouvé dans $GLACIER_JSON"
  exit 1
fi

echo "📋 Vaults trouvés :"
echo "$VAULTS" | sed 's/^/  - /'
echo ""

# Pour chaque vault, lancer un job d'inventaire
for VAULT in $VAULTS; do
  echo "=============================="
  echo "📦 Vault : $VAULT"

  # Lancer le job d'inventaire
  echo "🔄 Lancement du job d'inventaire..."
  JOB_OUTPUT=$(aws glacier initiate-job \
    --account-id "$ACCOUNT_ID" \
    --vault-name "$VAULT" \
    --region "$REGION" \
    --job-parameters '{"Type":"inventory-retrieval"}')

  # Extraire le job ID et location
  JOB_ID=$(echo "$JOB_OUTPUT" | jq -r '.jobId')
  LOCATION=$(echo "$JOB_OUTPUT" | jq -r '.location')

  if [[ -z "$JOB_ID" || "$JOB_ID" == "null" ]]; then
    echo "❌ Échec du lancement du job pour $VAULT"
    continue
  fi

  echo "✅ Job lancé avec succès"
  echo "   Job ID : $JOB_ID"
  echo "   Location : $LOCATION"

  # Sauvegarder le job dans un fichier job_<vault>.json
  JOB_FILE="$JOBS_DIR/job_${VAULT}.json"
  echo "$JOB_OUTPUT" > "$JOB_FILE"
  echo "💾 Job sauvegardé dans : $JOB_FILE"

  echo ""
done

echo "🎉 Tous les jobs d'inventaire ont été lancés !"
echo ""
echo "⏳ IMPORTANT : Les jobs d'inventaire Glacier prennent généralement 3-5 heures."
echo "   Utilisez check_glacier_jobs.sh pour vérifier l'état des jobs."
echo "   Une fois tous les jobs terminés, lancez delete_glacier_auto.sh pour nettoyer."
