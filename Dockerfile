FROM eclipse-temurin:25-jdk-jammy

WORKDIR /hycker

# Install dependencies and clean up
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    wget \
    curl \
    jq \
    python3 \
    python3-pip && \
    pip3 install --no-cache-dir gdown && \
    apt-get clean && \
    apt-get autoremove -y && \
    rm -rf /var/lib/apt/lists/*

# Set environment variables
ARG HYTALE_CURSEFORGE_API_KEY

ENV HYTALE_ASSETS_PATH="Assets.zip" \
    HYTALE_AUTH_MODE="authenticated" \
    HYTALE_BIND_ADDRESS="0.0.0.0:5520" \
    HYTALE_BACKUP_ENABLED="true" \
    HYTALE_BACKUP_FREQUENCY="30" \
    HYTALE_DISABLE_SENTRY="false" \
    JAVA_OPTS="-Xms1G -Xmx4G" \
    HYTALE_AUTO_UPDATE="false" \
    HYTALE_CURSEFORGE_API_KEY=${HYTALE_CURSEFORGE_API_KEY}

# Copy scripts
COPY entrypoint.sh /entrypoint.sh
COPY scripts/ /opt/hycker-scripts/

# Fix line endings and permissions
RUN sed -i 's/\r$//' /entrypoint.sh && \
    sed -i 's/\r$//' /opt/hycker-scripts/*.sh && \
    chmod +x /entrypoint.sh && chmod +r /entrypoint.sh && \
    chmod +x /opt/hycker-scripts/*.sh && chmod +r /opt/hycker-scripts/*.sh

# Create user and set ownership
RUN useradd -m -u 1000 hytale && \
    chown -R hytale:hytale /hycker /entrypoint.sh && \
    chmod 755 /hycker

# Metadata labels
LABEL maintainer="contact@jmbargueno.com" \
    name="jmbargueno/hycker" \
    github="https://github.com/jmbargueno/hycker" \
    dockerhub="https://hub.docker.com/r/jmbargueno/hycker" \
    description="Hycker - Hytale Server Docker Container"

# Health check
HEALTHCHECK --interval=30s --timeout=10s --retries=3 --start-period=60s \
    CMD sh -c "ps aux | grep -v grep | grep java || exit 1"

ENTRYPOINT ["/entrypoint.sh"]