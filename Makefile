.PHONY: help build start stop restart logs shell clean status exec

help:
	@echo "🐳 Glacier Manager - Commandes disponibles"
	@echo ""
	@echo "  make build      - Construire l'image Docker"
	@echo "  make start      - Démarrer le container"
	@echo "  make stop       - Arrêter le container"
	@echo "  make restart    - Redémarrer le container"
	@echo "  make logs       - Afficher les logs en temps réel"
	@echo "  make shell      - Ouvrir un shell dans le container"
	@echo "  make status     - Afficher l'état du container"
	@echo "  make clean      - Supprimer le container et l'image"
	@echo ""
	@echo "  make exec CMD='./check_glacier_jobs.sh'  - Exécuter une commande"
	@echo ""
	@echo "Dashboard : http://localhost:8080"

build:
	@echo "🔨 Construction de l'image Docker..."
	cd docker && docker compose build

start:
	@./scripts/docker-start.sh

stop:
	@./scripts/docker-stop.sh

restart: stop start

logs:
	@echo "📋 Logs en temps réel (Ctrl+C pour quitter)..."
	@cd docker && docker compose logs -f

shell:
	@./scripts/docker-shell.sh

status:
	@echo "📊 État du container :"
	@cd docker && docker compose ps
	@echo ""
	@echo "🌐 Dashboard : http://localhost:8080"

clean:
	@echo "🧹 Nettoyage..."
	@cd docker && docker compose down -v
	@docker rmi glacier-manager:latest 2>/dev/null || true
	@echo "✅ Nettoyage terminé"

exec:
	@cd docker && docker compose exec glacier-dashboard $(CMD)

# Raccourcis pour les scripts communs
init:
	@echo "🚀 Lancement des jobs d'inventaire..."
	@cd docker && docker compose exec glacier-dashboard ./scripts/init_glacier_inventory.sh

check:
	@echo "🔍 Vérification de l'état des jobs..."
	@cd docker && docker compose exec glacier-dashboard ./scripts/check_glacier_jobs.sh

delete-dry:
	@echo "🧪 Suppression en mode dry-run..."
	@cd docker && docker compose exec glacier-dashboard ./scripts/delete_glacier_auto.sh --dry-run

delete:
	@echo "⚠️  ATTENTION : Suppression RÉELLE des archives"
	@read -p "Êtes-vous sûr ? (yes/no) : " confirm && [ "$$confirm" = "yes" ]
	@cd docker && docker compose exec glacier-dashboard ./scripts/delete_glacier_auto.sh

vaults-only:
	@echo "📦 Suppression des vaults vides..."
	@cd docker && docker compose exec glacier-dashboard ./scripts/delete_glacier_auto.sh --vaults-only
