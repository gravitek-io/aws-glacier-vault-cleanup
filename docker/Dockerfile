FROM python:3.11-slim

# Métadonnées
LABEL maintainer="Glacier Manager"
LABEL description="Dashboard et scripts pour la gestion des vaults AWS Glacier"
LABEL version="1.0"

# Variables d'environnement
ENV PYTHONUNBUFFERED=1
ENV DEBIAN_FRONTEND=noninteractive

# Installer les dépendances système
RUN apt-get update && apt-get install -y \
    bash \
    curl \
    unzip \
    jq \
    bc \
    && rm -rf /var/lib/apt/lists/*

# Installer AWS CLI v2
RUN curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip" && \
    unzip awscliv2.zip && \
    ./aws/install && \
    rm -rf aws awscliv2.zip

# Créer un utilisateur non-root
RUN useradd -m -u 1000 glacier && \
    mkdir -p /home/glacier/app && \
    chown -R glacier:glacier /home/glacier

# Définir le répertoire de travail
WORKDIR /home/glacier/app

# Copier la structure du projet
COPY --chown=glacier:glacier scripts/ ./scripts/
COPY --chown=glacier:glacier web/ ./web/
COPY --chown=glacier:glacier data/glacier.json ./data/glacier.json

# Rendre les scripts exécutables
RUN chmod +x scripts/*.sh web/*.py

# Créer les répertoires nécessaires pour les données
RUN mkdir -p data/glacier_inventory data/glacier_logs data/job_data && \
    chown -R glacier:glacier data/

# Passer à l'utilisateur non-root
USER glacier

# Exposer le port du dashboard
EXPOSE 8080

# Healthcheck
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:8080/api/status || exit 1

# Point d'entrée par défaut : lancer le dashboard
CMD ["python3", "web/dashboard_server.py"]
