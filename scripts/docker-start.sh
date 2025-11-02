#!/usr/bin/env bash
set -euo pipefail

# Determine project root directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
DOCKER_DIR="$ROOT_DIR/docker"
DATA_DIR="$ROOT_DIR/data"

echo "🐳 Glacier Manager - Docker Edition"
echo "===================================="
echo ""

# Check that Docker is installed
if ! command -v docker &> /dev/null; then
    echo "❌ Error: Docker is not installed"
    echo "   Install Docker from https://www.docker.com/get-started"
    exit 1
fi

# Check that Docker Compose is available
if ! docker compose version &> /dev/null && ! docker-compose --version &> /dev/null; then
    echo "❌ Error: Docker Compose is not available"
    exit 1
fi

# Create necessary directories if they don't exist
mkdir -p "$DATA_DIR/glacier_inventory" "$DATA_DIR/glacier_logs" "$DATA_DIR/job_data"

# Check AWS credentials
if [[ ! -d "$HOME/.aws" ]]; then
    echo "⚠️  Warning: ~/.aws/ not found"
    echo "   Make sure you have configured your AWS credentials with 'aws configure'"
    read -p "   Continue anyway ? (y/N) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

echo "🔨 Building Docker image (may take a few minutes)..."
cd "$DOCKER_DIR"
docker compose build

echo ""
echo "🚀 Launching container..."
docker compose up -d

echo ""
echo "✅ Container launched successfully!"
echo ""
echo "📊 Dashboard available at: http://localhost:8080"
echo ""
echo "Useful commands:"
echo "  cd docker && docker compose logs -f              # View logs in real-time"
echo "  cd docker && docker compose ps                   # Container status"
echo "  cd docker && docker compose exec glacier-dashboard bash  # Open a shell"
echo "  cd docker && docker compose down                 # Stop the container"
echo "  make stop                            # Stop script"
echo ""
echo "To execute a script in the container:"
echo "  cd docker && docker compose exec glacier-dashboard ./scripts/init_glacier_inventory.sh"
echo "  cd docker && docker compose exec glacier-dashboard ./scripts/check_glacier_jobs.sh"
echo "  cd docker && docker compose exec glacier-dashboard ./scripts/delete_glacier_auto.sh --dry-run"
echo ""
echo "Or use Makefile shortcuts:"
echo "  make init        # Start inventory jobs"
echo "  make check       # Check jobs status"
echo "  make delete-dry  # Deletion in dry-run mode"
echo ""
