#!/usr/bin/env bash
set -euo pipefail

ACCOUNT_ID="-"               # Ton ID de compte (ou "-")
REGION="eu-west-1"           # Adapte selon ta région
JOBS_DIR="."                 # Dossier contenant les job*.json
TMP_DIR="./glacier_inventory"

mkdir -p "$TMP_DIR"

DRY_RUN=false
if [[ "${1:-}" == "--dry-run" ]]; then
  DRY_RUN=true
  echo "🔎 MODE DRY RUN activé : aucune suppression réelle ne sera faite"
fi

echo "🔍 Recherche des fichiers job*.json dans $JOBS_DIR..."
for JOB_FILE in "$JOBS_DIR"/job*.json; do
  [[ -f "$JOB_FILE" ]] || continue

  echo "=============================="
  echo "📄 Fichier : $JOB_FILE"

  VAULT=$(jq -r '.location' "$JOB_FILE" | sed -E 's#.*/vaults/([^/]+)/.*#\1#')
  JOB_ID=$(jq -r '.jobId' "$JOB_FILE")

  if [[ -z "$VAULT" || -z "$JOB_ID" || "$VAULT" == "null" ]]; then
    echo "⚠️  Impossible d’extraire vault/jobId depuis $JOB_FILE"
    continue
  fi

  echo "➡️  Vault : $VAULT"
  echo "➡️  Job ID : $JOB_ID"

  INVENTORY_FILE="$TMP_DIR/inventory_${VAULT}.json"

  echo "📥 Téléchargement de l'inventaire..."
  aws glacier get-job-output \
    --account-id "$ACCOUNT_ID" \
    --vault-name "$VAULT" \
    --job-id "$JOB_ID" \
    "$INVENTORY_FILE" \
    --region "$REGION"

  echo "✅ Inventaire sauvegardé : $INVENTORY_FILE"

  ARCHIVE_IDS=$(jq -r '.ArchiveList[].ArchiveId' "$INVENTORY_FILE" 2>/dev/null || true)

  if [[ -z "$ARCHIVE_IDS" ]]; then
    echo "⚠️  Aucune archive trouvée dans $VAULT"
  else
    echo "🧨 Archives trouvées :"
    echo "$ARCHIVE_IDS" | sed 's/^/  - /'
    
    if $DRY_RUN; then
      echo "🚫 DRY RUN → suppression simulée"
    else
      echo "🧹 Suppression réelle des archives..."
      for ID in $ARCHIVE_IDS; do
        [[ $ID == -* ]] && continue
        echo " - Suppression de l’archive $ID"
        aws glacier delete-archive \
          --account-id "$ACCOUNT_ID" \
          --vault-name "$VAULT" \
          --region "$REGION" \
          --archive-id "$ID"
      done
    fi
  fi

  if $DRY_RUN; then
    echo "🚫 DRY RUN → suppression simulée du vault $VAULT"
  else
    echo "🧹 Suppression du vault vide : $VAULT"
    aws glacier delete-vault \
      --account-id "$ACCOUNT_ID" \
      --vault-name "$VAULT" \
      --region "$REGION" \
      && echo "✅ Vault supprimé : $VAULT" \
      || echo "❌ Vault non encore vide ou erreur"
  fi
done

echo "🎉 Script terminé."

