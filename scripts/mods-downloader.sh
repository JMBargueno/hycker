#!/bin/bash

# mods-downloader.sh
# Orchestrates all mod downloaders in scripts/mods_downloaders
# Detects environment variables and calls the corresponding script
#
# HYCKER_MODS_ZIP_URL         -> download-mods-from-zip-url.sh
# HYCKER_MODS_GDRIVE_URL      -> download-mods-gdrive.sh
# HYCKER_MODS_CURSEFORGE_IDS  -> download-mods-curseforge.sh

set -e

SCRIPT_DIR="$(dirname "$0")"
DL_DIR="$SCRIPT_DIR/mods_downloaders"

if [ -n "$HYCKER_MODS_ZIP_URL" ]; then
  echo "[HYCKER - DOWNLOADER ORCHESTRATOR] Detected HYCKER_MODS_ZIP_URL. Calling download-mods-from-zip-url.sh..."
  bash "$DL_DIR/download-mods-from-zip-url.sh" "$HYCKER_MODS_ZIP_URL"
fi

if [ -n "$HYCKER_MODS_GDRIVE_URL" ]; then
  echo "[HYCKER - DOWNLOADER ORCHESTRATOR] Detected HYCKER_MODS_GDRIVE_URL. Calling download-mods-gdrive.sh..."
  bash "$DL_DIR/download-mods-gdrive.sh" "$HYCKER_MODS_GDRIVE_URL"
fi

if [ -n "$HYCKER_MODS_CURSEFORGE_IDS" ]; then
  echo "[HYCKER - DOWNLOADER ORCHESTRATOR] Detected HYCKER_MODS_CURSEFORGE_IDS. Calling download-mods-curseforge.sh..."
  bash "$DL_DIR/download-mods-curseforge.sh" "$HYCKER_MODS_CURSEFORGE_IDS"
fi

echo "[HYCKER - DOWNLOADER ORCHESTRATOR] All requested mod downloads completed."