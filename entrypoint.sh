#!/bin/bash
# Exit immediately if any command exits with a non-zero status
set -e

# Display ASCII art banner
echo ""
echo -e "\033[0;36m _   ___   _______ _  _______ ____  \033[0m"
echo -e "\033[0;36m| | | \\ \\ / / ____| |/ / ____|  _ \\ \033[0m"
echo -e "\033[0;36m| |_| |\\ V / |   | ' /|  _| | |_) |\033[0m"
echo -e "\033[0;36m|  _  | | || |___| . \\| |___|  _ < \033[0m"
echo -e "\033[0;36m|_| |_| |_| \\____|_|\\_\\_____|_| \\_\\\\\033[0m"
echo ""
echo "=========================================="
echo "  Hytale Server Docker Container v1.0.13"
echo -e "  \033[0;33mhttps://github.com/JMBargueno/hycker\033[0m"
echo "=========================================="
echo ""

# Source scripts
source /opt/hycker-scripts/download-server.sh
source /opt/hycker-scripts/backup-config.sh
source /opt/hycker-scripts/display-startup-info.sh
source /opt/hycker-scripts/mods-downloader.sh
# Change to the working directory where Hytale server files are located
cd /hycker



# Orchestrate mod downloads if any relevant env is set
if [ -n "$HYCKER_MODS_ZIP_URL" ] || [ -n "$HYCKER_MODS_GDRIVE_URL" ] || [ -n "$HYCKER_MODS_CURSEFORGE_IDS" ]; then
    echo "[HYCKER] Orchestrating mod downloads via mods-downloader.sh"
    if ! mods_downloader_main; then
        echo -e "\033[0;31m[HYCKER] Warning: Mod downloads failed, but continuing with server startup...\033[0m"
    fi
fi

# Download and extract server files if needed
download_and_extract_server

# Double-check that the server JAR file exists before starting
if [ -f "Server/HytaleServer.jar" ]; then
    SERVER_JAR="Server/HytaleServer.jar"
else
    echo "[HYCKER] ERROR: HytaleServer.jar not found!"
    exit 1
fi

# Set the path to the Assets.zip file
# Use the environment variable HYTALE_ASSETS_PATH if set, otherwise default to "Assets.zip"
ASSETS_PATH="${HYTALE_ASSETS_PATH:-Assets.zip}"

# If Assets.zip is not found in the current directory, look in the parent directory
if [ ! -f "$ASSETS_PATH" ]; then
    # Check if Assets.zip exists in the parent directory
    if [ -f "../$ASSETS_PATH" ]; then
        ASSETS_PATH="../$ASSETS_PATH"
    else
        # Warn if Assets.zip cannot be found (server may not start correctly)
        echo "[HYCKER] WARNING: Assets.zip not found. The server may not start correctly."
    fi
fi

# Build Java command using an array to avoid quote escaping issues

# Start with base Java command and options for heap memory configuration

# Add --accept-early-plugins if HYTALE_ACCEPT_EARLY_PLUGINS is set to true
declare -a java_args=(java ${JAVA_OPTS} -jar "$SERVER_JAR" --assets "$ASSETS_PATH")
if [ "${HYTALE_ACCEPT_EARLY_PLUGINS}" = "true" ]; then
    echo -e "\033[0;33m[WARNING] --accept-early-plugins is enabled. Early plugins will be accepted!\033[0m"
    java_args+=(--accept-early-plugins)
fi

# Add bind address for Docker compatibility (default: 0.0.0.0:5520)
if [ -n "${HYTALE_BIND_ADDRESS}" ]; then
    java_args+=(--bind "${HYTALE_BIND_ADDRESS}")
fi

# Add authentication mode if specified (authenticated or offline)
if [ -n "${HYTALE_AUTH_MODE}" ]; then
    java_args+=(--auth-mode "${HYTALE_AUTH_MODE}")
fi

# Configure backup options using the external script
configure_backup_options java_args

# Disable Sentry crash reporting if specified
if [ "${HYTALE_DISABLE_SENTRY}" = "true" ]; then
    java_args+=(--disable-sentry)
fi

# Append HYTALE_ADDITIONAL_ARGS to JAVA_OPTS if set
if [ -n "${HYTALE_ADDITIONAL_ARGS}" ]; then
    # Yellow: \033[1;33m ... \033[0m
    echo -e "\033[1;33m[HYCKER] Additional Java args: ${HYTALE_ADDITIONAL_ARGS}\033[0m"
    # shellcheck disable=SC2206
    additional_args=( ${HYTALE_ADDITIONAL_ARGS} )
    java_args+=( "${additional_args[@]}" )
fi

# Display startup information using the external script
display_startup_info "$SERVER_JAR" "$ASSETS_PATH" java_args

# Start the Hytale server with the configured options
# 'exec' replaces the shell process with the Java process
exec "${java_args[@]}"
