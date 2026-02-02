#!/bin/bash

# download_mods_curseforge <mod_id1,mod_id2,...>
# Downloads mods from CurseForge using batch API request
# Usage: HYTALE_CURSEFORGE_API_KEY=your_key ./download-mods-curseforge.sh <mod_id1,mod_id2,...>

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

function download_mods_curseforge() {
  local API_KEY="${HYTALE_CURSEFORGE_API_KEY}"
  local MOD_IDS="$1"
  local DEST_DIR="data/mods"
  local BASE_URL="https://api.curseforge.com"

  # Validate inputs
  if [[ -z "$API_KEY" ]]; then
    echo -e "${RED}[HYCKER - CURSEFORGE DOWNLOADER] Error: HYTALE_CURSEFORGE_API_KEY environment variable not set${NC}"
    return 1
  fi

  if [[ -z "$MOD_IDS" ]]; then
    if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
      echo -e "${RED}[HYCKER - CURSEFORGE DOWNLOADER] Usage: $0 <mod_id1,mod_id2,...>${NC}"
    else
      echo -e "${RED}[HYCKER - CURSEFORGE DOWNLOADER] Usage: download_mods_curseforge <mod_id1,mod_id2,...>${NC}"
    fi
    return 1
  fi

  # Ensure jq is available
  if ! command -v jq &> /dev/null; then
    echo -e "${YELLOW}[HYCKER - CURSEFORGE DOWNLOADER] Installing jq...${NC}"
    apt-get update && apt-get install -y jq
  fi

  # Create destination directory
  mkdir -p "$DEST_DIR"

  # Convert mod IDs to JSON array
  echo "[HYCKER - CURSEFORGE DOWNLOADER] Processing mod IDs: $MOD_IDS"
  local MOD_IDS_ARRAY
  IFS=',' read -ra MOD_IDS_ARRAY <<< "$MOD_IDS"
  
  # Build JSON array manually to ensure proper formatting
  local JSON_ARRAY="["
  local first=true
  for mod_id in "${MOD_IDS_ARRAY[@]}"; do
    mod_id=$(echo "$mod_id" | xargs) # trim whitespace
    if [[ ! "$mod_id" =~ ^[0-9]+$ ]]; then
      echo -e "${RED}[HYCKER - CURSEFORGE DOWNLOADER] Warning: Invalid mod ID '$mod_id' (not numeric), skipping${NC}"
      continue
    fi
    if [[ "$first" == true ]]; then
      first=false
    else
      JSON_ARRAY+=","
    fi
    JSON_ARRAY+="$mod_id"
  done
  JSON_ARRAY+="]"

  if [[ "$JSON_ARRAY" == "[]" ]]; then
    echo -e "${RED}[HYCKER - CURSEFORGE DOWNLOADER] Error: No valid mod IDs provided${NC}"
    return 1
  fi

  # Prepare request body
  local REQUEST_BODY="{\"modIds\":$JSON_ARRAY,\"filterPcOnly\":true}"
  echo "[HYCKER - CURSEFORGE DOWNLOADER] Request body: $REQUEST_BODY"
  echo "[HYCKER - CURSEFORGE DOWNLOADER] API Key (first 10 chars): ${API_KEY:0:10}..."
  echo "[HYCKER - CURSEFORGE DOWNLOADER] API Key length: ${#API_KEY}"

  # Make API request to get mod information
  echo "[HYCKER - CURSEFORGE DOWNLOADER] Fetching mod information from CurseForge..."
  local RESPONSE
  RESPONSE=$(curl -s -w "\n%{http_code}" \
    -H "Accept: application/json" \
    -H "Content-Type: application/json" \
    -H "x-api-key: $API_KEY" \
    -X POST "$BASE_URL/v1/mods" \
    -d "$REQUEST_BODY")

  # Extract HTTP status and body
  local HTTP_CODE
  HTTP_CODE=$(echo "$RESPONSE" | tail -n1)
  local BODY
  BODY=$(echo "$RESPONSE" | head -n -1)

  # Check HTTP status
  if [[ "$HTTP_CODE" != "200" ]]; then
    echo -e "${RED}[HYCKER - CURSEFORGE DOWNLOADER] API Error: HTTP $HTTP_CODE${NC}"
    echo "Response: $BODY"
    return 1
  fi

  # Parse response
  local MODS_DATA
  if ! MODS_DATA=$(echo "$BODY" | jq -r '.data // empty' 2>/dev/null); then
    echo -e "${RED}[HYCKER - CURSEFORGE DOWNLOADER] Error: Invalid JSON response${NC}"
    echo "Response: $BODY"
    return 1
  fi

  if [[ -z "$MODS_DATA" || "$MODS_DATA" == "null" ]]; then
    echo -e "${RED}[HYCKER - CURSEFORGE DOWNLOADER] Error: No 'data' field in API response${NC}"
    echo "Full response: $BODY"
    return 1
  fi

  local MODS_COUNT
  MODS_COUNT=$(echo "$MODS_DATA" | jq 'length')

  if [[ "$MODS_COUNT" -eq 0 ]]; then
    echo -e "${RED}[HYCKER - CURSEFORGE DOWNLOADER] No mods found for the provided IDs${NC}"
    echo "API returned empty data array"
    return 1
  fi

  echo -e "${GREEN}[HYCKER - CURSEFORGE DOWNLOADER] Found $MODS_COUNT mod(s)${NC}"

  # Process each mod
  for ((i=0; i<MODS_COUNT; i++)); do
    local MOD_INFO
    MOD_INFO=$(echo "$MODS_DATA" | jq ".[$i]")
    
    local MOD_ID MOD_NAME MAIN_FILE_ID
    MOD_ID=$(echo "$MOD_INFO" | jq -r '.id')
    MOD_NAME=$(echo "$MOD_INFO" | jq -r '.name')
    MAIN_FILE_ID=$(echo "$MOD_INFO" | jq -r '.mainFileId // empty')

    echo ""
    echo -e "${GREEN}[HYCKER - CURSEFORGE DOWNLOADER] Mod: $MOD_NAME (ID: $MOD_ID, Main File ID: ${MAIN_FILE_ID:-"none"})${NC}"

    if [[ -z "$MAIN_FILE_ID" || "$MAIN_FILE_ID" == "null" ]]; then
      echo -e "${YELLOW}[HYCKER - CURSEFORGE DOWNLOADER] Warning: Mod '$MOD_NAME' has no main file, skipping${NC}"
      continue
    fi

    # Get download URL for main file
    echo "[HYCKER - CURSEFORGE DOWNLOADER] Getting download URL for file $MAIN_FILE_ID..."
    local DL_RESPONSE DL_HTTP_CODE DL_BODY DL_URL
    DL_RESPONSE=$(curl -s -w "\n%{http_code}" \
      -H "Accept: application/json" \
      -H "x-api-key: $API_KEY" \
      "$BASE_URL/v1/mods/$MOD_ID/files/$MAIN_FILE_ID/download-url")

    DL_HTTP_CODE=$(echo "$DL_RESPONSE" | tail -n1)
    DL_BODY=$(echo "$DL_RESPONSE" | head -n -1)

    if [[ "$DL_HTTP_CODE" != "200" ]]; then
      echo -e "${RED}[HYCKER - CURSEFORGE DOWNLOADER] Error: Failed to get download URL (HTTP $DL_HTTP_CODE)${NC}"
      continue
    fi

    DL_URL=$(echo "$DL_BODY" | jq -r '.data // empty')
    if [[ -z "$DL_URL" || "$DL_URL" == "null" ]]; then
      echo -e "${RED}[HYCKER - CURSEFORGE DOWNLOADER] Error: Invalid download URL response${NC}"
      continue
    fi

    # Get filename from file info
    local FILE_INFO_RESPONSE FILE_INFO_HTTP_CODE FILE_INFO_BODY FILE_NAME
    FILE_INFO_RESPONSE=$(curl -s -w "\n%{http_code}" \
      -H "Accept: application/json" \
      -H "x-api-key: $API_KEY" \
      "$BASE_URL/v1/mods/$MOD_ID/files/$MAIN_FILE_ID")

    FILE_INFO_HTTP_CODE=$(echo "$FILE_INFO_RESPONSE" | tail -n1)
    FILE_INFO_BODY=$(echo "$FILE_INFO_RESPONSE" | head -n -1)

    if [[ "$FILE_INFO_HTTP_CODE" == "200" ]]; then
      FILE_NAME=$(echo "$FILE_INFO_BODY" | jq -r '.data.fileName // empty')
    fi

    if [[ -z "$FILE_NAME" || "$FILE_NAME" == "null" ]]; then
      FILE_NAME="mod_${MOD_ID}_file_${MAIN_FILE_ID}.jar"
      echo -e "${YELLOW}[HYCKER - CURSEFORGE DOWNLOADER] Warning: Could not get filename, using: $FILE_NAME${NC}"
    fi

    # Download the file
    echo "[HYCKER - CURSEFORGE DOWNLOADER] Downloading: $FILE_NAME"
    if curl -L --fail "$DL_URL" -o "$DEST_DIR/$FILE_NAME"; then
      echo -e "${GREEN}[HYCKER - CURSEFORGE DOWNLOADER] ✓ Downloaded '$MOD_NAME' as $DEST_DIR/$FILE_NAME${NC}"
      echo "[HYCKER - CURSEFORGE DOWNLOADER] Summary: '$MOD_NAME' (ID: $MOD_ID) → $FILE_NAME"
    else
      echo -e "${RED}[HYCKER - CURSEFORGE DOWNLOADER] ✗ Failed to download '$MOD_NAME'${NC}"
    fi

    # Rate limiting
    sleep 0.5
  done

  echo ""
  echo -e "${GREEN}[HYCKER - CURSEFORGE DOWNLOADER] Mod downloads completed!${NC}"
}

# Export function for use by orchestrator
export -f download_mods_curseforge

# If script is run directly, execute the function
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  download_mods_curseforge "$1"
fi
