#!/usr/bin/env bash
set -euo pipefail

ACCOUNT_ID="-"               # Ton ID de compte (ou "-")
REGION="eu-west-1"           # Adapte selon ta région
JOBS_DIR="."                 # Dossier contenant les job*.json
TMP_DIR="./glacier_inventory"
DELAY_BETWEEN_DELETES=0.5    # Délai en secondes pour éviter le rate limiting
MAX_RETRIES=3                # Nombre de tentatives en cas d'erreur

mkdir -p "$TMP_DIR"

DRY_RUN=false
VAULTS_ONLY=false

# Parse les arguments
for arg in "$@"; do
  case $arg in
    --dry-run)
      DRY_RUN=true
      echo "🔎 MODE DRY RUN activé : aucune suppression réelle ne sera faite"
      ;;
    --vaults-only)
      VAULTS_ONLY=true
      echo "🗑️  MODE VAULTS ONLY : suppression uniquement des vaults vides"
      ;;
    *)
      echo "❌ Argument inconnu : $arg"
      echo "Usage: $0 [--dry-run] [--vaults-only]"
      exit 1
      ;;
  esac
done

echo "🔍 Recherche des fichiers job*.json dans $JOBS_DIR..."
TOTAL_VAULTS=0
VAULTS_DELETED=0
VAULTS_FAILED=0

for JOB_FILE in "$JOBS_DIR"/job*.json; do
  [[ -f "$JOB_FILE" ]] || continue

  TOTAL_VAULTS=$((TOTAL_VAULTS + 1))
  echo ""
  echo "=============================="
  echo "📄 Fichier : $JOB_FILE"

  VAULT=$(jq -r '.location' "$JOB_FILE" | sed -E 's#.*/vaults/([^/]+)/.*#\1#')
  JOB_ID=$(jq -r '.jobId' "$JOB_FILE")

  if [[ -z "$VAULT" || -z "$JOB_ID" || "$VAULT" == "null" ]]; then
    echo "⚠️  Impossible d'extraire vault/jobId depuis $JOB_FILE"
    VAULTS_FAILED=$((VAULTS_FAILED + 1))
    continue
  fi

  echo "➡️  Vault : $VAULT"
  echo "➡️  Job ID : $JOB_ID"

  INVENTORY_FILE="$TMP_DIR/inventory_${VAULT}.json"

  # Vérifier le statut du job avant de télécharger
  if [[ ! -f "$INVENTORY_FILE" ]] && [[ "$VAULTS_ONLY" == false ]]; then
    echo "🔍 Vérification du statut du job..."
    JOB_STATUS=$(aws glacier describe-job \
      --account-id "$ACCOUNT_ID" \
      --vault-name "$VAULT" \
      --job-id "$JOB_ID" \
      --region "$REGION")

    COMPLETED=$(echo "$JOB_STATUS" | jq -r '.Completed')
    STATUS_CODE=$(echo "$JOB_STATUS" | jq -r '.StatusCode')

    if [[ "$COMPLETED" != "true" ]] || [[ "$STATUS_CODE" != "Succeeded" ]]; then
      echo "❌ Le job n'est pas terminé (Statut: $STATUS_CODE)"
      echo "   Lancez ./check_glacier_jobs.sh pour vérifier l'état"
      VAULTS_FAILED=$((VAULTS_FAILED + 1))
      continue
    fi
    echo "✅ Job terminé avec succès"
  fi

  # Télécharger l'inventaire si nécessaire
  if [[ ! -f "$INVENTORY_FILE" ]] && [[ "$VAULTS_ONLY" == false ]]; then
    echo "📥 Téléchargement de l'inventaire..."
    if aws glacier get-job-output \
      --account-id "$ACCOUNT_ID" \
      --vault-name "$VAULT" \
      --job-id "$JOB_ID" \
      "$INVENTORY_FILE" \
      --region "$REGION"; then
      echo "✅ Inventaire sauvegardé : $INVENTORY_FILE"
    else
      echo "❌ Échec du téléchargement de l'inventaire"
      VAULTS_FAILED=$((VAULTS_FAILED + 1))
      continue
    fi
  fi

  # Traiter les archives (sauf en mode --vaults-only)
  if [[ "$VAULTS_ONLY" == false ]]; then
    # Valider le JSON et extraire les archives
    if ! jq empty "$INVENTORY_FILE" 2>/dev/null; then
      echo "❌ Fichier JSON invalide : $INVENTORY_FILE"
      VAULTS_FAILED=$((VAULTS_FAILED + 1))
      continue
    fi

    ARCHIVE_COUNT=$(jq -r '.ArchiveList | length' "$INVENTORY_FILE" 2>/dev/null || echo "0")

    if [[ "$ARCHIVE_COUNT" -eq 0 ]]; then
      echo "⚠️  Aucune archive trouvée dans $VAULT"
    else
      echo "🧨 $ARCHIVE_COUNT archives trouvées dans le vault"

      if $DRY_RUN; then
        echo "🚫 DRY RUN → suppression de $ARCHIVE_COUNT archives simulée"
      else
        echo "🧹 Suppression réelle des archives..."
        SUCCESS_COUNT=0
        FAILED_COUNT=0
        CURRENT=0

        while IFS= read -r ID; do
          CURRENT=$((CURRENT + 1))
          [[ -z "$ID" || "$ID" == "null" || "$ID" == -* ]] && continue

          # Afficher la progression tous les 100 archives
          if (( CURRENT % 100 == 0 )); then
            echo "   Progression: $CURRENT/$ARCHIVE_COUNT archives traitées..."
          fi

          # Tentatives avec retry
          RETRY_COUNT=0
          SUCCESS=false

          while [[ $RETRY_COUNT -lt $MAX_RETRIES ]] && [[ "$SUCCESS" == false ]]; do
            if aws glacier delete-archive \
              --account-id "$ACCOUNT_ID" \
              --vault-name "$VAULT" \
              --region "$REGION" \
              --archive-id "$ID" 2>/dev/null; then
              SUCCESS=true
              SUCCESS_COUNT=$((SUCCESS_COUNT + 1))
            else
              RETRY_COUNT=$((RETRY_COUNT + 1))
              if [[ $RETRY_COUNT -lt $MAX_RETRIES ]]; then
                echo "   ⚠️  Erreur sur archive ${ID:0:20}..., tentative $((RETRY_COUNT + 1))/$MAX_RETRIES"
                sleep 2
              fi
            fi
          done

          if [[ "$SUCCESS" == false ]]; then
            echo "   ❌ Échec définitif: ${ID:0:20}..."
            FAILED_COUNT=$((FAILED_COUNT + 1))
          fi

          # Pause pour éviter le rate limiting
          sleep "$DELAY_BETWEEN_DELETES"
        done < <(jq -r '.ArchiveList[].ArchiveId' "$INVENTORY_FILE")

        echo "✅ Suppression terminée : $SUCCESS_COUNT réussies, $FAILED_COUNT échouées"

        if [[ $FAILED_COUNT -gt 0 ]]; then
          echo "⚠️  Des archives n'ont pas pu être supprimées, le vault ne pourra pas être supprimé"
          VAULTS_FAILED=$((VAULTS_FAILED + 1))
          continue
        fi
      fi
    fi
  fi

  # Suppression du vault
  if $DRY_RUN; then
    echo "🚫 DRY RUN → suppression simulée du vault $VAULT"
    VAULTS_DELETED=$((VAULTS_DELETED + 1))
  else
    echo "🧹 Suppression du vault vide : $VAULT"
    echo "   ⚠️  Note : La suppression peut échouer si le vault a été modifié il y a moins de 24h"

    if aws glacier delete-vault \
      --account-id "$ACCOUNT_ID" \
      --vault-name "$VAULT" \
      --region "$REGION" 2>/dev/null; then
      echo "✅ Vault supprimé : $VAULT"
      VAULTS_DELETED=$((VAULTS_DELETED + 1))
    else
      echo "❌ Échec de suppression du vault $VAULT"
      echo "   Raisons possibles :"
      echo "   - Le vault contient encore des archives"
      echo "   - Le vault a été modifié il y a moins de 24h"
      echo "   - Permissions AWS insuffisantes"
      echo ""
      echo "💡 Pour réessayer plus tard : ./delete_glacier_auto.sh --vaults-only"
      VAULTS_FAILED=$((VAULTS_FAILED + 1))
    fi
  fi
done

echo ""
echo "=============================="
echo "📊 RÉSUMÉ FINAL"
echo "=============================="
echo "Total de vaults traités : $TOTAL_VAULTS"
echo "✅ Vaults supprimés : $VAULTS_DELETED"
echo "❌ Échecs : $VAULTS_FAILED"
echo ""

if [[ $VAULTS_FAILED -gt 0 ]] && [[ "$DRY_RUN" == false ]]; then
  echo "⚠️  Certains vaults n'ont pas pu être supprimés."
  echo "   Attendez 24h puis relancez : ./delete_glacier_auto.sh --vaults-only"
fi

echo "🎉 Script terminé."

