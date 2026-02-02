#!/bin/bash

# download_mods_curseforge <mod_id1,mod_id2,...>
# Downloads mods from CurseForge by numeric mod IDs (not slugs)
# Usage: HYTALE_CURSEFORGE_API_KEY=your_key ./download-mods-curseforge.sh <mod_id1,mod_id2,...>

set -e

RED='\033[0;31m'
NC='\033[0m'

function download_mods_curseforge() {
  API_KEY="${HYTALE_CURSEFORGE_API_KEY}"
  MOD_IDS="$1"
  DEST_DIR="data/mods"
  BASE_URL="https://api.curseforge.com"
  GAME_ID=70216 # Hytale gameId (replace if different)

  if [ -z "$API_KEY" ]; then
    echo -e "${RED}[HYCKER - CURSEFORGE DOWNLOADER] You must set the HYTALE_CURSEFORGE_API_KEY environment variable.${NC}"
    return 1
  fi
  if [ -z "$MOD_IDS" ]; then
    if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
      echo -e "${RED}[HYCKER - CURSEFORGE DOWNLOADER] Usage: $0 <mod_id1,mod_id2,...>${NC}"
    else
      echo -e "${RED}[HYCKER - CURSEFORGE DOWNLOADER] Usage: download_mods_curseforge <mod_id1,mod_id2,...>${NC}"
    fi
    return 1
  fi
  if ! command -v jq &> /dev/null; then
    echo -e "${RED}[HYCKER - CURSEFORGE DOWNLOADER] This script requires jq. Installing...${NC}"
    apt-get update && apt-get install -y jq
  fi

  mkdir -p "$DEST_DIR"
  IFS=',' read -ra IDS <<< "$MOD_IDS"
  for MOD_ID in "${IDS[@]}"; do
    MOD_ID_TRIM=$(echo "$MOD_ID" | xargs)
    if [ -z "$MOD_ID_TRIM" ]; then
      continue
    fi
    echo "[HYCKER - CURSEFORGE DOWNLOADER] Getting latest file for mod ID: $MOD_ID_TRIM ..."
    FILES_JSON=$(curl -s -H "Accept: application/json" -H "x-api-key: $API_KEY" "$BASE_URL/v1/mods/$MOD_ID_TRIM/files?pageSize=1")
    FILE_ID=$(echo "$FILES_JSON" | jq -r '.data[0].id')
    FILE_NAME=$(echo "$FILES_JSON" | jq -r '.data[0].fileName')
    if [ "$FILE_ID" = "null" ] || [ -z "$FILE_ID" ]; then
      echo -e "${RED}[HYCKER - CURSEFORGE DOWNLOADER] No files found for mod $MOD_ID_TRIM${NC}"
      continue
    fi
    echo "[HYCKER - CURSEFORGE DOWNLOADER] Latest file ID: $FILE_ID ($FILE_NAME)"
    DL_JSON=$(curl -s -H "Accept: application/json" -H "x-api-key: $API_KEY" "$BASE_URL/v1/mods/$MOD_ID_TRIM/files/$FILE_ID/download-url")
    DL_URL=$(echo "$DL_JSON" | jq -r '.data')
    if [ "$DL_URL" = "null" ] || [ -z "$DL_URL" ]; then
      echo -e "${RED}[HYCKER - CURSEFORGE DOWNLOADER] Could not get download URL for file $FILE_ID${NC}"
      continue
    fi
    echo "[HYCKER - CURSEFORGE DOWNLOADER] Downloading $DL_URL ..."
    curl -L "$DL_URL" -o "$DEST_DIR/$FILE_NAME"
    echo "[HYCKER - CURSEFORGE DOWNLOADER] Mod $MOD_ID_TRIM downloaded to $DEST_DIR/$FILE_NAME"
    sleep 1
    # To avoid rate limiting
  done
}

# If run directly, call the function
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  download_mods_curseforge "$1"
fi

export -f download_mods_curseforge
