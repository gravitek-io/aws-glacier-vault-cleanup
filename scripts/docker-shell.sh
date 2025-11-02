#!/usr/bin/env bash
set -euo pipefail

# Déterminer le répertoire racine du projet
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
DOCKER_DIR="$ROOT_DIR/docker"

echo "🐚 Ouverture d'un shell dans le container..."
echo ""

cd "$DOCKER_DIR"
docker compose exec glacier-dashboard bash
