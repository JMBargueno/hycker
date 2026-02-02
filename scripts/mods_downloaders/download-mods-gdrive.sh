#!/bin/bash

# download_mods_gdrive <gdrive_url>
# Downloads all files from a Google Drive folder URL into /hycker/mods
# Usage: download_mods_gdrive <gdrive_folder_url>

set -e
RED='\033[0;31m'
NC='\033[0m'

function download_mods_gdrive() {
  GDRIVE_URL="$1"
  DEST_DIR="/hycker/mods"
  TMP_DIR="/tmp/hycker_gdrive_$$"
  mkdir -p "$DEST_DIR"
  mkdir -p "$TMP_DIR"

  if ! command -v gdown &> /dev/null; then
    echo -e "${RED}[HYCKER - GDRIVE DOWNLOADER] gdown is required for Google Drive downloads. Installing...${NC}"
    pip install gdown
  fi

  echo "[HYCKER - GDRIVE DOWNLOADER] Downloading all files from Google Drive folder: $GDRIVE_URL ..."
  gdown --folder "$GDRIVE_URL" -O "$TMP_DIR"

  # Move all files to DEST_DIR (flatten structure)
  find "$TMP_DIR" -type f ! -name '*.zip' -exec cp {} "$DEST_DIR" \;
  echo "[HYCKER - GDRIVE DOWNLOADER] Files downloaded to $DEST_DIR"
  rm -rf "$TMP_DIR"
}

# If run directly, call the function
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  if [ -z "$1" ]; then
    echo -e "${RED}[HYCKER - GDRIVE DOWNLOADER] Usage: $0 <gdrive_folder_url>${NC}"
    exit 1
  fi
  download_mods_gdrive "$1"
fi

export -f download_mods_gdrive
