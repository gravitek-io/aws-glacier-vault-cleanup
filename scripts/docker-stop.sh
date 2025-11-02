#!/usr/bin/env bash
set -euo pipefail

# Determine project root directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
DOCKER_DIR="$ROOT_DIR/docker"

echo "🛑 Stopping Glacier Manager..."
echo ""

cd "$DOCKER_DIR"
docker compose down

echo ""
echo "✅ Container stopped"
echo ""
echo "Data persists in:"
echo "  - $ROOT_DIR/data/glacier_inventory/"
echo "  - $ROOT_DIR/data/glacier_logs/"
echo "  - $ROOT_DIR/data/job_data/"
echo ""
echo "To restart: make start"
echo ""
