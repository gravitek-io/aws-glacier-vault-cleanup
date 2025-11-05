.PHONY: help build start stop restart logs shell clean clean-logs status exec init check delete-dry delete vaults-only

help:
	@echo "🐳 Glacier Manager - Available Commands"
	@echo ""
	@echo "Container Management:"
	@echo "  make build         - Build Docker image"
	@echo "  make start         - Start container"
	@echo "  make stop          - Stop container"
	@echo "  make restart       - Restart container"
	@echo "  make logs          - Show real-time logs"
	@echo "  make shell         - Open shell in container"
	@echo "  make status        - Show container status"
	@echo "  make clean         - Remove container and image"
	@echo "  make clean-logs    - Delete all data files (logs, jobs, inventories, glacier.json)"
	@echo ""
	@echo "Glacier Operations:"
	@echo "  make init          - Launch inventory jobs"
	@echo "  make check         - Check job status"
	@echo "  make delete-dry    - Deletion in dry-run mode"
	@echo "  make delete        - Real deletion (asks for confirmation)"
	@echo "  make vaults-only   - Delete only empty vaults"
	@echo ""
	@echo "Advanced:"
	@echo "  make exec CMD='...' - Execute custom command in container"
	@echo ""
	@echo "Dashboard: http://localhost:8080"

build:
	@echo "🔨 Building Docker image..."
	cd docker && docker compose build

start:
	@./scripts/docker-start.sh

stop:
	@./scripts/docker-stop.sh

restart: stop start

logs:
	@echo "📋 Real-time logs (Ctrl+C to quit)..."
	@cd docker && docker compose logs -f

shell:
	@./scripts/docker-shell.sh

status:
	@echo "📊 Container status:"
	@cd docker && docker compose ps
	@echo ""
	@echo "🌐 Dashboard : http://localhost:8080"

clean:
	@echo "🧹 Cleaning..."
	@cd docker && docker compose down -v
	@docker rmi glacier-manager:latest 2>/dev/null || true
	@echo "✅ Cleaning completed"

clean-logs:
	@echo "🧹 Deleting log files, jobs, inventories and glacier.json..."
	@rm -rf data/glacier_logs/*
	@rm -f data/job_*.json
	@rm -rf data/glacier_inventory/*
	@rm -f data/glacier.json
	@echo "✅ All data files deleted"

exec:
	@cd docker && docker compose exec glacier-dashboard $(CMD)

# Shortcuts for common scripts
init:
	@echo "🚀 Launching inventory jobs..."
	@cd docker && docker compose exec glacier-dashboard ./scripts/init_glacier_inventory.sh

check:
	@echo "🔍 Checking job status..."
	@cd docker && docker compose exec glacier-dashboard ./scripts/check_glacier_jobs.sh

delete-dry:
	@echo "🧪 Deletion in dry-run mode..."
	@cd docker && docker compose exec glacier-dashboard ./scripts/delete_glacier_auto.sh --dry-run

delete:
	@echo "⚠️  WARNING: REAL deletion of archives"
	@read -p "Are you sure ? (yes/no) : " confirm && [ "$$confirm" = "yes" ]
	@cd docker && docker compose exec glacier-dashboard ./scripts/delete_glacier_auto.sh

vaults-only:
	@echo "📦 Deleting empty vaults..."
	@cd docker && docker compose exec glacier-dashboard ./scripts/delete_glacier_auto.sh --vaults-only
