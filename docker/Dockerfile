FROM python:3.11-slim

# Metadata
LABEL maintainer="Glacier Manager"
LABEL description="Dashboard and scripts for AWS Glacier vault management"
LABEL version="1.0"

# Environment variables
ENV PYTHONUNBUFFERED=1
ENV DEBIAN_FRONTEND=noninteractive

# Install system dependencies
RUN apt-get update && apt-get install -y \
    bash \
    curl \
    unzip \
    jq \
    bc \
    && rm -rf /var/lib/apt/lists/*

# Install AWS CLI v2
RUN curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip" && \
    unzip awscliv2.zip && \
    ./aws/install && \
    rm -rf aws awscliv2.zip

# Create non-root user
RUN useradd -m -u 1000 glacier && \
    mkdir -p /home/glacier/app && \
    chown -R glacier:glacier /home/glacier

# Set working directory
WORKDIR /home/glacier/app

# Copy project structure
COPY --chown=glacier:glacier scripts/ ./scripts/
COPY --chown=glacier:glacier web/ ./web/

# Make scripts executable
RUN chmod +x scripts/*.sh web/*.py

# Create directories for data
RUN mkdir -p data/glacier_inventory data/glacier_logs data/job_data && \
    chown -R glacier:glacier data/

# Switch to non-root user
USER glacier

# Expose dashboard port
EXPOSE 8080

# Healthcheck
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:8080/api/status || exit 1

# Default entrypoint: run the dashboard
CMD ["python3", "web/dashboard_server.py"]
