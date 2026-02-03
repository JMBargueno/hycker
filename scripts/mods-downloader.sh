#!/bin/bash

# mods-downloader.sh
# Orchestrates all mod downloaders in /opt/hycker-scripts/mods_downloaders
# Detects environment variables and calls the corresponding function from each script
#
# HYCKER_MODS_ZIP_URL         -> download_mods_from_zip_url
# HYCKER_MODS_GDRIVE_URL      -> download_mods_gdrive
# HYCKER_MODS_CURSEFORGE_IDS  -> download_mods_curseforge

set -e

MODS_DIR="/opt/hycker-scripts/mods_downloaders"

# Source all mods_downloaders scripts to export their functions
source "$MODS_DIR/download-mods-from-zip-url.sh"
source "$MODS_DIR/download-mods-gdrive.sh"
source "$MODS_DIR/download-mods-curseforge.sh"

mods_downloader_main() {
  local ANY_MODS=false

  if [ -n "$HYCKER_MODS_ZIP_URL" ]; then
    echo "[HYCKER - DOWNLOADER ORCHESTRATOR] Detected HYCKER_MODS_ZIP_URL. Calling download_mods_from_zip_url..."
    download_mods_from_zip_url "$HYCKER_MODS_ZIP_URL"
    ANY_MODS=true
  fi

  if [ -n "$HYCKER_MODS_GDRIVE_URL" ]; then
    echo "[HYCKER - DOWNLOADER ORCHESTRATOR] Detected HYCKER_MODS_GDRIVE_URL. Calling download_mods_gdrive..."
    download_mods_gdrive "$HYCKER_MODS_GDRIVE_URL"
    ANY_MODS=true
  fi

  if [ -n "$HYCKER_MODS_CURSEFORGE_IDS" ]; then
    echo "[HYCKER - DOWNLOADER ORCHESTRATOR] Detected HYCKER_MODS_CURSEFORGE_IDS. Calling download_mods_curseforge..."
    download_mods_curseforge "$HYCKER_MODS_CURSEFORGE_IDS"
    ANY_MODS=true
  fi

  if [ "$ANY_MODS" = false ]; then
    echo "[HYCKER - DOWNLOADER ORCHESTRATOR] No mods detected to install."
  else
    echo "[HYCKER - DOWNLOADER ORCHESTRATOR] All requested mod downloads completed."
  fi
}

export -f mods_downloader_main

# Only run if called directly, not sourced
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  mods_downloader_main "$@"
fi