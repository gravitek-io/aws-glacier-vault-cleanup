#!/usr/bin/env bash
set -euo pipefail

echo "🛑 Arrêt du Glacier Manager..."
echo ""

docker compose down

echo ""
echo "✅ Container arrêté"
echo ""
echo "Les données persistent dans :"
echo "  - ./glacier_inventory/"
echo "  - ./glacier_logs/"
echo "  - ./job_data/"
echo ""
echo "Pour redémarrer : ./docker-start.sh"
echo ""
