#!/usr/bin/env bash

# Determine project root directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"

echo "🚀 Launching AWS Glacier Dashboard..."
echo ""

# Check that Python 3 is installed
if ! command -v python3 &> /dev/null; then
    echo "❌ Error: Python 3 is not installed"
    echo "   Install Python 3 from https://www.python.org/"
    exit 1
fi

# Check that files exist
if [[ ! -f "$ROOT_DIR/data/glacier.json" ]]; then
    echo "⚠️  Warning: data/glacier.json not found"
fi

# Start server from root directory
cd "$ROOT_DIR"
python3 web/dashboard_server.py
