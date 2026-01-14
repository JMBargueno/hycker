#!/bin/bash
# backup-config.sh
# Configures backup options for Hytale server

# This script adds backup-related arguments to the java_args array
# The java_args array should be declared before calling this function

configure_backup_options() {
    local java_args_ref=$1
    
    # Add backup options if enabled
    if [ "${HYTALE_BACKUP_ENABLED}" = "true" ]; then
        echo -e "\033[0;32m[HYCKER] Backup is enabled\033[0m"
        
        # Enable backup flag
        eval "${java_args_ref}+=(--backup)"
        
        # Add backup directory if specified
        if [ -n "${HYTALE_BACKUP_DIR}" ]; then
            echo -e "\033[0;32m[HYCKER] Backup directory: ${HYTALE_BACKUP_DIR}\033[0m"
            eval "${java_args_ref}+=(--backup-dir \"${HYTALE_BACKUP_DIR}\")"
        fi
        
        # Add backup frequency in minutes if specified
        if [ -n "${HYTALE_BACKUP_FREQUENCY}" ]; then
            echo -e "\033[0;32m[HYCKER] Backup frequency: ${HYTALE_BACKUP_FREQUENCY} minutes\033[0m"
            eval "${java_args_ref}+=(--backup-frequency \"${HYTALE_BACKUP_FREQUENCY}\")"
        fi
    else
        echo -e "\033[0;31m[HYCKER] Backup is disabled\033[0m"
    fi
}

# Export the function so it can be used by the entrypoint script
export -f configure_backup_options
