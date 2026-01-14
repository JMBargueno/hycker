#!/bin/bash
# display-startup-info.sh
# Displays startup information with all configured options

# This function displays the server configuration before starting
# Parameters:
#   $1 - SERVER_JAR path
#   $2 - ASSETS_PATH path
#   $3 - Reference to java_args array

display_startup_info() {
    local server_jar=$1
    local assets_path=$2
    local java_args_ref=$3
    
    # Display startup information with all configured options
    echo -e "\033[0;32m[HYCKER] Starting Hytale server with configuration:\033[0m"
    echo -e "\033[0;32m[HYCKER] JAR: $server_jar\033[0m"
    echo -e "\033[0;32m[HYCKER] Assets: $assets_path\033[0m"
    echo -e "\033[0;32m[HYCKER] Bind Address: ${HYTALE_BIND_ADDRESS:-0.0.0.0:5520}\033[0m"
    echo -e "\033[0;32m[HYCKER] Auth Mode: ${HYTALE_AUTH_MODE:-default (authenticated)}\033[0m"
    echo -e "\033[0;32m[HYCKER] Backup Enabled: ${HYTALE_BACKUP_ENABLED:-false}\033[0m"
    echo -e "\033[0;32m[HYCKER] Java Options: ${JAVA_OPTS}\033[0m"
    echo ""
    
    # Show the exact command that will be executed
    echo -e "\033[0;33m[HYCKER] Java command to execute:\033[0m"
    eval "echo -e \"\033[0;33m[HYCKER] \${${java_args_ref}[*]}\033[0m\""
    echo ""
}

# Export the function so it can be used by the entrypoint script
export -f display_startup_info
