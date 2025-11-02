#!/usr/bin/env bash

# Déterminer le répertoire racine du projet
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"

echo "🚀 Lancement du Dashboard AWS Glacier..."
echo ""

# Vérifier que Python 3 est installé
if ! command -v python3 &> /dev/null; then
    echo "❌ Erreur: Python 3 n'est pas installé"
    echo "   Installez Python 3 depuis https://www.python.org/"
    exit 1
fi

# Vérifier que les fichiers existent
if [[ ! -f "$ROOT_DIR/data/glacier.json" ]]; then
    echo "⚠️  Avertissement: data/glacier.json introuvable"
fi

# Lancer le serveur depuis le répertoire racine
cd "$ROOT_DIR"
python3 web/dashboard_server.py
