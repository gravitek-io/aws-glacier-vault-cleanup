#!/usr/bin/env bash
set -euo pipefail

# Determine project root directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
DOCKER_DIR="$ROOT_DIR/docker"

echo "🐚 Opening a shell in the container..."
echo ""

cd "$DOCKER_DIR"
docker compose exec glacier-dashboard bash
