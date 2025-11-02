#!/usr/bin/env bash
set -euo pipefail

ACCOUNT_ID="-"               # Ton ID de compte (ou "-")
REGION="eu-west-1"           # Adapte selon ta région
JOBS_DIR="."                 # Dossier contenant les job*.json
TMP_DIR="./glacier_inventory"
LOG_DIR="./glacier_logs"
DELAY_BETWEEN_DELETES=0.5    # Délai en secondes pour éviter le rate limiting
MAX_RETRIES=3                # Nombre de tentatives en cas d'erreur

mkdir -p "$TMP_DIR" "$LOG_DIR"

# Initialiser le fichier de log avec timestamp
LOG_FILE="$LOG_DIR/deletion_$(date +%Y%m%d_%H%M%S).log"

# Fonction de logging
log() {
  local level="$1"
  shift
  local message="$@"
  local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
  echo "[$timestamp] [$level] $message" | tee -a "$LOG_FILE"
}

# Fonction pour gérer l'interruption propre (Ctrl+C)
cleanup_on_exit() {
  log "WARN" "Script interrompu par l'utilisateur (Ctrl+C)"
  log "INFO" "La progression a été sauvegardée. Relancez le script pour reprendre."
  exit 130
}

trap cleanup_on_exit SIGINT SIGTERM

log "INFO" "=== Démarrage du script de suppression Glacier ==="
log "INFO" "Fichier de log : $LOG_FILE"

DRY_RUN=false
VAULTS_ONLY=false

# Parse les arguments
for arg in "$@"; do
  case $arg in
    --dry-run)
      DRY_RUN=true
      log "INFO" "MODE DRY RUN activé"
      echo "🔎 MODE DRY RUN activé : aucune suppression réelle ne sera faite"
      ;;
    --vaults-only)
      VAULTS_ONLY=true
      log "INFO" "MODE VAULTS ONLY activé"
      echo "🗑️  MODE VAULTS ONLY : suppression uniquement des vaults vides"
      ;;
    *)
      log "ERROR" "Argument inconnu : $arg"
      echo "❌ Argument inconnu : $arg"
      echo "Usage: $0 [--dry-run] [--vaults-only]"
      exit 1
      ;;
  esac
done

log "INFO" "Recherche des fichiers job*.json dans $JOBS_DIR..."
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
    log "ERROR" "Impossible d'extraire vault/jobId depuis $JOB_FILE"
    echo "⚠️  Impossible d'extraire vault/jobId depuis $JOB_FILE"
    VAULTS_FAILED=$((VAULTS_FAILED + 1))
    continue
  fi

  log "INFO" "Traitement du vault : $VAULT (Job ID: $JOB_ID)"
  echo "➡️  Vault : $VAULT"
  echo "➡️  Job ID : $JOB_ID"

  INVENTORY_FILE="$TMP_DIR/inventory_${VAULT}.json"
  WORKING_INVENTORY="$TMP_DIR/inventory_${VAULT}.working.json"
  PROGRESS_FILE="$TMP_DIR/.progress_${VAULT}"

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
    # Vérifier si une copie de travail existe (reprise après interruption)
    if [[ -f "$WORKING_INVENTORY" ]]; then
      log "INFO" "Reprise détectée : utilisation de la copie de travail pour $VAULT"
      echo "🔄 Reprise détectée : utilisation de l'inventaire de travail existant"
      ACTIVE_INVENTORY="$WORKING_INVENTORY"
    elif [[ -f "$INVENTORY_FILE" ]]; then
      # Créer une copie de travail pour la première fois
      log "INFO" "Création de la copie de travail pour $VAULT"
      cp "$INVENTORY_FILE" "$WORKING_INVENTORY"
      ACTIVE_INVENTORY="$WORKING_INVENTORY"
    else
      log "ERROR" "Aucun inventaire trouvé pour $VAULT"
      echo "❌ Aucun inventaire trouvé"
      VAULTS_FAILED=$((VAULTS_FAILED + 1))
      continue
    fi

    # Valider le JSON et extraire les archives
    if ! jq empty "$ACTIVE_INVENTORY" 2>/dev/null; then
      log "ERROR" "Fichier JSON invalide : $ACTIVE_INVENTORY"
      echo "❌ Fichier JSON invalide : $ACTIVE_INVENTORY"
      VAULTS_FAILED=$((VAULTS_FAILED + 1))
      continue
    fi

    ARCHIVE_COUNT=$(jq -r '.ArchiveList | length' "$ACTIVE_INVENTORY" 2>/dev/null || echo "0")
    ORIGINAL_COUNT=$(jq -r '.ArchiveList | length' "$INVENTORY_FILE" 2>/dev/null || echo "$ARCHIVE_COUNT")

    if [[ "$ARCHIVE_COUNT" -eq 0 ]]; then
      log "INFO" "Aucune archive à supprimer dans $VAULT"
      echo "⚠️  Aucune archive trouvée dans $VAULT"
      # Nettoyer la copie de travail
      rm -f "$WORKING_INVENTORY" "$PROGRESS_FILE"
    else
      if [[ "$ARCHIVE_COUNT" -lt "$ORIGINAL_COUNT" ]]; then
        ALREADY_DELETED=$((ORIGINAL_COUNT - ARCHIVE_COUNT))
        log "INFO" "$ALREADY_DELETED/$ORIGINAL_COUNT archives déjà supprimées lors d'une exécution précédente"
        echo "🔄 Reprise : $ALREADY_DELETED/$ORIGINAL_COUNT archives déjà supprimées"
      fi

      log "INFO" "$ARCHIVE_COUNT archives restantes dans le vault $VAULT"
      echo "🧨 $ARCHIVE_COUNT archives trouvées dans le vault"

      if $DRY_RUN; then
        log "INFO" "DRY RUN : simulation de suppression de $ARCHIVE_COUNT archives"
        echo "🚫 DRY RUN → suppression de $ARCHIVE_COUNT archives simulée"
      else
        echo "🧹 Suppression réelle des archives..."
        log "INFO" "Début de la suppression de $ARCHIVE_COUNT archives"

        SUCCESS_COUNT=0
        FAILED_COUNT=0
        CURRENT=0
        START_TIME=$(date +%s)

        while IFS= read -r ID; do
          CURRENT=$((CURRENT + 1))
          [[ -z "$ID" || "$ID" == "null" || "$ID" == -* ]] && continue

          # Afficher la progression tous les 100 archives
          if (( CURRENT % 100 == 0 )); then
            ELAPSED=$(($(date +%s) - START_TIME))
            RATE=$(echo "scale=2; $CURRENT / $ELAPSED" | bc 2>/dev/null || echo "?")
            REMAINING=$((ARCHIVE_COUNT - CURRENT))
            if [[ "$RATE" != "?" ]] && (( $(echo "$RATE > 0" | bc -l) )); then
              ETA=$(echo "scale=0; $REMAINING / $RATE / 60" | bc 2>/dev/null || echo "?")
              echo "   Progression: $CURRENT/$ARCHIVE_COUNT archives ($RATE/s, ETA: ${ETA}min)..."
              log "INFO" "Progression: $CURRENT/$ARCHIVE_COUNT archives traitées"
            else
              echo "   Progression: $CURRENT/$ARCHIVE_COUNT archives traitées..."
            fi
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

              # Supprimer l'archive du fichier de travail
              TEMP_JSON=$(mktemp)
              jq --arg id "$ID" '.ArchiveList = [.ArchiveList[] | select(.ArchiveId != $id)]' "$ACTIVE_INVENTORY" > "$TEMP_JSON"
              mv "$TEMP_JSON" "$ACTIVE_INVENTORY"

              # Sauvegarder la progression
              echo "$SUCCESS_COUNT" > "$PROGRESS_FILE"
            else
              RETRY_COUNT=$((RETRY_COUNT + 1))
              if [[ $RETRY_COUNT -lt $MAX_RETRIES ]]; then
                log "WARN" "Erreur sur archive ${ID:0:20}..., tentative $((RETRY_COUNT + 1))/$MAX_RETRIES"
                echo "   ⚠️  Erreur sur archive ${ID:0:20}..., tentative $((RETRY_COUNT + 1))/$MAX_RETRIES"
                sleep 2
              fi
            fi
          done

          if [[ "$SUCCESS" == false ]]; then
            log "ERROR" "Échec définitif de suppression : ${ID:0:40}"
            echo "   ❌ Échec définitif: ${ID:0:20}..."
            FAILED_COUNT=$((FAILED_COUNT + 1))
          fi

          # Pause pour éviter le rate limiting
          sleep "$DELAY_BETWEEN_DELETES"
        done < <(jq -r '.ArchiveList[].ArchiveId' "$ACTIVE_INVENTORY")

        log "INFO" "Suppression terminée pour $VAULT : $SUCCESS_COUNT réussies, $FAILED_COUNT échouées"
        echo "✅ Suppression terminée : $SUCCESS_COUNT réussies, $FAILED_COUNT échouées"

        if [[ $FAILED_COUNT -gt 0 ]]; then
          log "WARN" "Des archives n'ont pas pu être supprimées dans $VAULT"
          echo "⚠️  Des archives n'ont pas pu être supprimées, le vault ne pourra pas être supprimé"
          echo "💡 Vous pouvez relancer le script pour réessayer uniquement les archives restantes"
          VAULTS_FAILED=$((VAULTS_FAILED + 1))
          continue
        else
          # Tout s'est bien passé, nettoyer les fichiers de progression
          log "INFO" "Toutes les archives de $VAULT ont été supprimées avec succès"
          rm -f "$WORKING_INVENTORY" "$PROGRESS_FILE"
        fi
      fi
    fi
  fi

  # Suppression du vault
  if $DRY_RUN; then
    log "INFO" "DRY RUN : simulation de suppression du vault $VAULT"
    echo "🚫 DRY RUN → suppression simulée du vault $VAULT"
    VAULTS_DELETED=$((VAULTS_DELETED + 1))
  else
    log "INFO" "Tentative de suppression du vault $VAULT"
    echo "🧹 Suppression du vault vide : $VAULT"
    echo "   ⚠️  Note : La suppression peut échouer si le vault a été modifié il y a moins de 24h"

    if aws glacier delete-vault \
      --account-id "$ACCOUNT_ID" \
      --vault-name "$VAULT" \
      --region "$REGION" 2>/dev/null; then
      log "INFO" "Vault supprimé avec succès : $VAULT"
      echo "✅ Vault supprimé : $VAULT"
      VAULTS_DELETED=$((VAULTS_DELETED + 1))

      # Nettoyer les fichiers associés
      rm -f "$INVENTORY_FILE" "$WORKING_INVENTORY" "$PROGRESS_FILE" "$JOBS_DIR/job_${VAULT}.json"
      log "INFO" "Fichiers temporaires nettoyés pour $VAULT"
    else
      log "ERROR" "Échec de suppression du vault $VAULT"
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
log "INFO" "=== Résumé final ==="
echo "=============================="
echo "📊 RÉSUMÉ FINAL"
echo "=============================="
echo "Total de vaults traités : $TOTAL_VAULTS"
echo "✅ Vaults supprimés : $VAULTS_DELETED"
echo "❌ Échecs : $VAULTS_FAILED"
echo ""

log "INFO" "Total: $TOTAL_VAULTS vaults, Supprimés: $VAULTS_DELETED, Échecs: $VAULTS_FAILED"

if [[ $VAULTS_FAILED -gt 0 ]] && [[ "$DRY_RUN" == false ]]; then
  log "WARN" "Certains vaults n'ont pas pu être supprimés"
  echo "⚠️  Certains vaults n'ont pas pu être supprimés."
  echo "   Attendez 24h puis relancez : ./delete_glacier_auto.sh --vaults-only"
fi

log "INFO" "=== Script terminé avec succès ==="
log "INFO" "Log complet disponible dans : $LOG_FILE"
echo "🎉 Script terminé."
echo ""
echo "📄 Log complet : $LOG_FILE"

