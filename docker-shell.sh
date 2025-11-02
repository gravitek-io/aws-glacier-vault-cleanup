#!/usr/bin/env bash
set -euo pipefail

echo "🐚 Ouverture d'un shell dans le container..."
echo ""

docker compose exec glacier-dashboard bash
