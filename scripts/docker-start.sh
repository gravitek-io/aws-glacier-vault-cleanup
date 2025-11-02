#!/usr/bin/env bash
set -euo pipefail

# Déterminer le répertoire racine du projet
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
DOCKER_DIR="$ROOT_DIR/docker"
DATA_DIR="$ROOT_DIR/data"

echo "🐳 Glacier Manager - Docker Edition"
echo "===================================="
echo ""

# Vérifier que Docker est installé
if ! command -v docker &> /dev/null; then
    echo "❌ Erreur: Docker n'est pas installé"
    echo "   Installez Docker depuis https://www.docker.com/get-started"
    exit 1
fi

# Vérifier que Docker Compose est disponible
if ! docker compose version &> /dev/null && ! docker-compose --version &> /dev/null; then
    echo "❌ Erreur: Docker Compose n'est pas disponible"
    exit 1
fi

# Créer les répertoires nécessaires s'ils n'existent pas
mkdir -p "$DATA_DIR/glacier_inventory" "$DATA_DIR/glacier_logs" "$DATA_DIR/job_data"

# Vérifier les credentials AWS
if [[ ! -d "$HOME/.aws" ]]; then
    echo "⚠️  Avertissement: ~/.aws/ introuvable"
    echo "   Assurez-vous d'avoir configuré vos credentials AWS avec 'aws configure'"
    read -p "   Continuer quand même ? (y/N) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

echo "🔨 Construction de l'image Docker (peut prendre quelques minutes)..."
cd "$DOCKER_DIR"
docker compose build

echo ""
echo "🚀 Lancement du container..."
docker compose up -d

echo ""
echo "✅ Container lancé avec succès !"
echo ""
echo "📊 Dashboard disponible à : http://localhost:8080"
echo ""
echo "Commandes utiles :"
echo "  cd docker && docker compose logs -f              # Voir les logs en temps réel"
echo "  cd docker && docker compose ps                   # État du container"
echo "  cd docker && docker compose exec glacier-dashboard bash  # Ouvrir un shell"
echo "  cd docker && docker compose down                 # Arrêter le container"
echo "  make stop                            # Script d'arrêt"
echo ""
echo "Pour exécuter un script dans le container :"
echo "  cd docker && docker compose exec glacier-dashboard ./scripts/init_glacier_inventory.sh"
echo "  cd docker && docker compose exec glacier-dashboard ./scripts/check_glacier_jobs.sh"
echo "  cd docker && docker compose exec glacier-dashboard ./scripts/delete_glacier_auto.sh --dry-run"
echo ""
echo "Ou utilisez les raccourcis Makefile :"
echo "  make init        # Lancer les jobs d'inventaire"
echo "  make check       # Vérifier l'état des jobs"
echo "  make delete-dry  # Suppression en mode dry-run"
echo ""
