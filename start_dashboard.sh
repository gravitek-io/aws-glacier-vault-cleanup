#!/usr/bin/env bash

echo "🚀 Lancement du Dashboard AWS Glacier..."
echo ""

# Vérifier que Python 3 est installé
if ! command -v python3 &> /dev/null; then
    echo "❌ Erreur: Python 3 n'est pas installé"
    echo "   Installez Python 3 depuis https://www.python.org/"
    exit 1
fi

# Vérifier que les scripts existent
if [[ ! -f "glacier.json" ]]; then
    echo "⚠️  Avertissement: glacier.json introuvable"
fi

# Lancer le serveur
python3 dashboard_server.py
