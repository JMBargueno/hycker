echo "Mod descargado y copiado a $MODS_DIR"

#!/bin/bash
# Function to download a ZIP, extract it, and move its contents to data/mods

set -e

download_mod_zip() {
  local ZIP_URL="$1"
  local MODS_DIR="$(dirname "$0")/../data/mods"
  local TMP_DIR="/tmp/hycker_mod_zip"

  if [ -z "$ZIP_URL" ]; then
    echo "Usage: download_mod_zip <zip_url>"
    return 1
  fi

  mkdir -p "$MODS_DIR"
  rm -rf "$TMP_DIR"
  mkdir -p "$TMP_DIR"

  local ZIP_FILE="$TMP_DIR/mod.zip"

  # Download the ZIP
  curl -L "$ZIP_URL" -o "$ZIP_FILE"

  # Extract the ZIP in the temporary directory
  unzip -o "$ZIP_FILE" -d "$TMP_DIR/unzipped"

  # Move the extracted contents to data/mods
  cp -r "$TMP_DIR/unzipped"/* "$MODS_DIR"/

  # Clean up
  rm -rf "$TMP_DIR"

  echo "Mod downloaded and copied to $MODS_DIR"
}

# Allow the script to be executed directly
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  download_mod_zip "$1"
fi
