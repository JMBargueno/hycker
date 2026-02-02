#!/bin/bash

# download_mods_from_zip_url <zip_url>
# Downloads a ZIP file from a direct URL, extracts it, and copies its contents into /hycker/mods
# Usage: download_mods_from_zip_url <zip_url>

set -e
RED='\033[0;31m'
NC='\033[0m'

function download_mods_from_zip_url() {
  ZIP_URL="$1"
  DEST_DIR="/hycker/mods"
  TMP_DIR="/tmp/hycker_zip_url_$$"
  mkdir -p "$DEST_DIR"
  mkdir -p "$TMP_DIR"

  echo "[HYCKER - ZIP DOWNLOADER] Downloading ZIP from $ZIP_URL ..."
  curl -L "$ZIP_URL" -o "$TMP_DIR/mod.zip"
  unzip -o "$TMP_DIR/mod.zip" -d "$TMP_DIR"

  # Move all files to DEST_DIR (flatten structure)
  find "$TMP_DIR" -type f ! -name '*.zip' -exec cp {} "$DEST_DIR" \;
  echo "[HYCKER - ZIP DOWNLOADER] Files extracted to $DEST_DIR"
  rm -rf "$TMP_DIR"
}

# If run directly, call the function
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  if [ -z "$1" ]; then
    echo -e "${RED}[HYCKER - ZIP DOWNLOADER] Usage: $0 <zip_url>${NC}"
    exit 1
  fi
  download_mods_from_zip_url "$1"
fi

export -f download_mods_from_zip_url
