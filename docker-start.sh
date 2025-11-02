#!/usr/bin/env bash
set -euo pipefail

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
mkdir -p glacier_inventory glacier_logs job_data

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
echo "  docker compose logs -f              # Voir les logs en temps réel"
echo "  docker compose ps                   # État du container"
echo "  docker compose exec glacier-dashboard bash  # Ouvrir un shell dans le container"
echo "  docker compose down                 # Arrêter le container"
echo "  ./docker-stop.sh                    # Script d'arrêt"
echo ""
echo "Pour exécuter un script dans le container :"
echo "  docker compose exec glacier-dashboard ./init_glacier_inventory.sh"
echo "  docker compose exec glacier-dashboard ./check_glacier_jobs.sh"
echo "  docker compose exec glacier-dashboard ./delete_glacier_auto.sh --dry-run"
echo ""
