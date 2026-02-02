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

ANY_MODS=false

if [ -n "$HYCKER_MODS_ZIP_URL" ]; then
  echo "[HYCKER - DOWNLOADER ORCHESTRATOR] Detected HYCKER_MODS_ZIP_URL. Calling download-mods-from-zip-url.sh..."
  bash "$DL_DIR/download-mods-from-zip-url.sh" "$HYCKER_MODS_ZIP_URL"
  ANY_MODS=true
fi

if [ -n "$HYCKER_MODS_GDRIVE_URL" ]; then
  echo "[HYCKER - DOWNLOADER ORCHESTRATOR] Detected HYCKER_MODS_GDRIVE_URL. Calling download-mods-gdrive.sh..."
  bash "$DL_DIR/download-mods-gdrive.sh" "$HYCKER_MODS_GDRIVE_URL"
  ANY_MODS=true
fi

if [ -n "$HYCKER_MODS_CURSEFORGE_IDS" ]; then
  echo "[HYCKER - DOWNLOADER ORCHESTRATOR] Detected HYCKER_MODS_CURSEFORGE_IDS. Calling download-mods-curseforge.sh..."
  bash "$DL_DIR/download-mods-curseforge.sh" "$HYCKER_MODS_CURSEFORGE_IDS"
  ANY_MODS=true
fi

if [ "$ANY_MODS" = false ]; then
  echo "[HYCKER - DOWNLOADER ORCHESTRATOR] No mods detected to install."
else
  echo "[HYCKER - DOWNLOADER ORCHESTRATOR] All requested mod downloads completed."
fi