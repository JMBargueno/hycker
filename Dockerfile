FROM eclipse-temurin:25-jdk-jammy

WORKDIR /hycker

# Install dependencies
# Update package list, install minimal required tools (wget, unzip, curl, python3, pip)
# Install gdown for Google Drive downloads
# Finally, remove apt cache to reduce image size
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    wget \
    unzip \
    curl \
    jq \
    python3 \
    python3-pip && \
    pip3 install --no-cache-dir gdown && \
    mkdir -p /hycker/data && \
    mkdir -p /opt/hycker-scripts && \
    rm -rf /var/lib/apt/lists/*

ARG HYTALE_CURSEFORGE_API_KEY

# Set environment variables for Hytale server configuration
# These can be overridden at runtime with docker run -e
ENV HYTALE_ASSETS_PATH="Assets.zip" \
    HYTALE_AUTH_MODE="authenticated" \
    HYTALE_BIND_ADDRESS="0.0.0.0:5520" \
    HYTALE_BACKUP_ENABLED="true" \
    HYTALE_BACKUP_FREQUENCY="30" \
    HYTALE_DISABLE_SENTRY="false" \
    JAVA_OPTS="-Xms1G -Xmx4G" \
    HYTALE_AUTO_UPDATE="false" \
    HYTALE_CURSEFORGE_API_KEY=${HYTALE_CURSEFORGE_API_KEY}

# Copy entrypoint script and scripts folder from host to container
COPY entrypoint.sh /entrypoint.sh
COPY scripts/ /opt/hycker-scripts/

# Convert line endings from CRLF to LF and make scripts executable
RUN sed -i 's/\r$//' /entrypoint.sh && \
    sed -i 's/\r$//' /opt/hycker-scripts/*.sh && \
    chmod +x /entrypoint.sh && chmod +r /entrypoint.sh && \
    chmod +x /opt/hycker-scripts/*.sh && chmod +r /opt/hycker-scripts/*.sh

# Create a non-root user 'hytale' with UID 1000 for better security
# Change ownership of the application directory and entrypoint script to the new user
RUN useradd -m -u 1000 hytale && \
    chown -R hytale:hytale /hycker /entrypoint.sh && \
    chmod 755 /hycker && \
    chmod 777 /hycker

# Keep running as root for file operations, will change user context in entrypoint if needed
# USER hytale

# Metadata labels
LABEL maintainer="contact@jmbargueno.com" \
    name="jmbargueno/hycker" \
    github="https://github.com/jmbargueno/hycker" \
    dockerhub="https://hub.docker.com/r/jmbargueno/hycker" \
    description="Hycker - Hytale Server Docker Container"

# Health check to verify the server is running
HEALTHCHECK --interval=30s --timeout=10s --retries=3 --start-period=60s \
    CMD sh -c "ps aux | grep -v grep | grep java || exit 1"

ENTRYPOINT ["/entrypoint.sh"]