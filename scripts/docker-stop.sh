#!/usr/bin/env bash
set -euo pipefail

# Déterminer le répertoire racine du projet
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
DOCKER_DIR="$ROOT_DIR/docker"

echo "🛑 Arrêt du Glacier Manager..."
echo ""

cd "$DOCKER_DIR"
docker compose down

echo ""
echo "✅ Container arrêté"
echo ""
echo "Les données persistent dans :"
echo "  - $ROOT_DIR/data/glacier_inventory/"
echo "  - $ROOT_DIR/data/glacier_logs/"
echo "  - $ROOT_DIR/data/job_data/"
echo ""
echo "Pour redémarrer : make start"
echo ""
