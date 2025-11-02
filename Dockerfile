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

# Copier les fichiers de l'application
COPY --chown=glacier:glacier *.sh ./
COPY --chown=glacier:glacier *.py ./
COPY --chown=glacier:glacier *.html ./
COPY --chown=glacier:glacier glacier.json ./

# Rendre les scripts exécutables
RUN chmod +x *.sh *.py

# Créer les répertoires nécessaires
RUN mkdir -p glacier_inventory glacier_logs && \
    chown -R glacier:glacier glacier_inventory glacier_logs

# Passer à l'utilisateur non-root
USER glacier

# Exposer le port du dashboard
EXPOSE 8080

# Healthcheck
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:8080/api/status || exit 1

# Point d'entrée par défaut : lancer le dashboard
CMD ["python3", "dashboard_server.py"]
