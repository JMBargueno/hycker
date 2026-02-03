#!/bin/bash
# CurseForge Mod Downloader - Batch API Version
# Downloads mods from CurseForge using batch POST API request
# Usage: ./download-mods-curseforge.sh <mod_id1,mod_id2,...>

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
API_KEY="${HYTALE_CURSEFORGE_API_KEY}"
BASE_URL="https://api.curseforge.com"
DEST_DIR="/hycker/mods"

function log() {
    local level="$1"
    local message="$2"
    
    case "$level" in
        "INFO")  echo -e "${BLUE}[HYCKER - CurseForge Batch Mod Downloader - INFO]${NC} $message" ;;
        "OK")    echo -e "${GREEN}[HYCKER - CurseForge Batch Mod Downloader - OK]${NC} $message" ;;
        "WARN")  echo -e "${YELLOW}[HYCKER - CurseForge Batch Mod Downloader - WARN]${NC} $message" ;;
        "ERROR") echo -e "${RED}[HYCKER - CurseForge Batch Mod Downloader - ERROR]${NC} $message" ;;
        *)       echo "$message" ;;
    esac
}

function check_dependencies() {
    log "INFO" "Checking dependencies..."
    
    # Check curl
    if ! command -v curl &> /dev/null; then
        log "ERROR" "curl is required but not installed"
        exit 1
    fi
    
    # Check jq
    if ! command -v jq &> /dev/null; then
        log "WARN" "jq not found, installing..."
        if command -v apt-get &> /dev/null; then
            apt-get update -qq && apt-get install -y -qq jq
        else
            log "ERROR" "Cannot install jq - apt-get not available"
            exit 1
        fi
    fi
    
    log "OK" "All dependencies ready"
}

function fetch_mods_batch() {
    local mod_ids="$1"
    
    # Convert comma-separated string to JSON array
    local json_array="["
    local first=true
    IFS=',' read -ra MOD_ARRAY <<< "$mod_ids"
    
    for mod_id in "${MOD_ARRAY[@]}"; do
        mod_id=$(echo "$mod_id" | xargs)  # trim whitespace
        
        # Validate mod ID is numeric
        if ! [[ "$mod_id" =~ ^[0-9]+$ ]]; then
            log "WARN" "Skipping invalid mod ID: $mod_id"
            continue
        fi
        
        if [[ "$first" == true ]]; then
            first=false
        else
            json_array+=","
        fi
        json_array+="$mod_id"
    done
    json_array+="]"
    
    if [[ "$json_array" == "[]" ]]; then
        log "ERROR" "No valid mod IDs provided"
        exit 1
    fi
    
    # Create the JSON payload
    local json_payload="{\"modIds\": $json_array, \"filterPcOnly\": true}"
    
    log "INFO" "Making batch API request for mod IDs: $json_array"
    log "INFO" "Payload: $json_payload"
    
    # Make the batch API request exactly like the working curl command
    local response
    response=$(curl -s -w "\n%{http_code}" \
        --location "$BASE_URL/v1/mods" \
        --header "x-api-key: $API_KEY" \
        --header "Content-Type: application/json" \
        --data "$json_payload")
    
    local http_code
    http_code=$(echo "$response" | tail -n1)
    local body
    body=$(echo "$response" | head -n -1)
    
    if [[ "$http_code" != "200" ]]; then
        log "ERROR" "Batch API request failed: HTTP $http_code"
        log "ERROR" "Response: $body"
        exit 1
    fi
    
    log "OK" "Batch API request successful"
    
    # Parse the response and extract mod data
    local mods_data
    mods_data=$(echo "$body" | jq -r '.data[]')
    
    if [[ -z "$mods_data" ]]; then
        log "ERROR" "No mod data found in API response"
        exit 1
    fi
    
    # Process each mod in the response
    echo "$body" | jq -c '.data[]' | while read -r mod; do
        download_mod_from_data "$mod"
    done
}

function extract_version() {
    local filename="$1"
    # Extract version pattern like 1.2.3, v1.2.3, 1.2, etc.
    echo "$filename" | grep -oP '(?:v)?[0-9]+\.[0-9]+(?:\.[0-9]+)?' | head -n1
}

function compare_versions() {
    local ver1="$1"
    local ver2="$2"
    
    # Remove 'v' prefix if present
    ver1="${ver1#v}"
    ver2="${ver2#v}"
    
    # Compare versions using sort -V (version sort)
    if [[ "$(printf '%s\n%s' "$ver1" "$ver2" | sort -V | head -n1)" == "$ver1" ]]; then
        if [[ "$ver1" == "$ver2" ]]; then
            echo "equal"
        else
            echo "older"
        fi
    else
        echo "newer"
    fi
}

function get_mod_base_name() {
    local filename="$1"
    # Remove version numbers and file extension to get base name
    echo "$filename" | sed -E 's/[-_]?v?[0-9]+\.[0-9]+(\.[0-9]+)?.*\.(jar|zip)$//' | sed 's/[-_]$//'
}

function download_mod_from_data() {
    local mod_data="$1"
    
    local mod_id mod_name main_file_id
    mod_id=$(echo "$mod_data" | jq -r '.id')
    mod_name=$(echo "$mod_data" | jq -r '.name')
    main_file_id=$(echo "$mod_data" | jq -r '.mainFileId // empty')
    
    log "INFO" "Processing: $mod_name (ID: $mod_id)"
    
    if [[ -z "$main_file_id" || "$main_file_id" == "null" ]]; then
        log "WARN" "Mod '$mod_name' has no main file available"
        return
    fi
    
    log "INFO" "Main file ID: $main_file_id"
    
    # Get file name first to check if it already exists
    response=$(curl -s -w "\n%{http_code}" \
        --location "$BASE_URL/v1/mods/$mod_id/files/$main_file_id" \
        --header "x-api-key: $API_KEY")
    
    http_code=$(echo "$response" | tail -n1)
    body=$(echo "$response" | head -n -1)
    
    local filename
    if [[ "$http_code" == "200" ]]; then
        filename=$(echo "$body" | jq -r '.data.fileName')
    fi
    
    if [[ -z "$filename" || "$filename" == "null" ]]; then
        filename="mod_${mod_id}_${main_file_id}.jar"
        log "WARN" "Using generated filename: $filename"
    fi
    
    # Check for existing mods
    local filepath="$DEST_DIR/$filename"
    local base_name
    base_name=$(get_mod_base_name "$filename")
    local new_version
    new_version=$(extract_version "$filename")
    
    # Find existing mods with similar base name
    local existing_mods
    existing_mods=$(find "$DEST_DIR" -maxdepth 1 -type f \( -name "*.jar" -o -name "*.zip" \) 2>/dev/null || true)
    
    local found_exact=false
    local found_older=false
    local older_file=""
    
    while IFS= read -r existing_file; do
        [[ -z "$existing_file" ]] && continue
        
        local existing_basename
        existing_basename=$(basename "$existing_file")
        
        # Check if it's the exact same file
        if [[ "$existing_basename" == "$filename" ]]; then
            log "OK" "Mod '$mod_name' already downloaded: $filename (skipping)"
            found_exact=true
            return
        fi
        
        # Check if it's the same mod (base name matches)
        local existing_base
        existing_base=$(get_mod_base_name "$existing_basename")
        
        if [[ "$existing_base" == "$base_name" ]] || [[ "$existing_basename" =~ $base_name ]]; then
            local existing_version
            existing_version=$(extract_version "$existing_basename")
            
            if [[ -n "$new_version" ]] && [[ -n "$existing_version" ]]; then
                local comparison
                comparison=$(compare_versions "$existing_version" "$new_version")
                
                if [[ "$comparison" == "older" ]]; then
                    log "INFO" "Found older version: $existing_basename (v$existing_version) -> upgrading to v$new_version"
                    found_older=true
                    older_file="$existing_file"
                elif [[ "$comparison" == "equal" ]]; then
                    log "OK" "Mod '$mod_name' already downloaded (same version): $existing_basename (skipping)"
                    found_exact=true
                    return
                elif [[ "$comparison" == "newer" ]]; then
                    log "WARN" "Existing version ($existing_version) is newer than download ($new_version), keeping existing"
                    found_exact=true
                    return
                fi
            fi
        fi
    done <<< "$existing_mods"
    
    [[ "$found_exact" == true ]] && return
    
    # Get download URL
    local response
    response=$(curl -s -w "\n%{http_code}" \
        --location "$BASE_URL/v1/mods/$mod_id/files/$main_file_id/download-url" \
        --header "x-api-key: $API_KEY")
    
    local http_code
    http_code=$(echo "$response" | tail -n1)
    local body
    body=$(echo "$response" | head -n -1)
    
    if [[ "$http_code" != "200" ]]; then
        log "ERROR" "Failed to get download URL for '$mod_name': HTTP $http_code"
        return
    fi
    
    local download_url
    download_url=$(echo "$body" | jq -r '.data')
    
    if [[ -z "$download_url" || "$download_url" == "null" ]]; then
        log "ERROR" "No download URL available for '$mod_name'"
        return
    fi
    
    # Download the file
    log "INFO" "Downloading: $filename"
    
    if curl -L --fail -sS "$download_url" -o "$filepath"; then
        log "OK" "Downloaded '$mod_name' -> $filename"
        
        # Remove older version if found
        if [[ "$found_older" == true ]] && [[ -n "$older_file" ]]; then
            log "INFO" "Removing old version: $(basename "$older_file")"
            rm -f "$older_file"
            log "OK" "Upgrade complete"
        fi
    else
        log "ERROR" "Failed to download '$mod_name'"
    fi
    
    # Small delay to be nice to the API
    sleep 0.5
}

function main() {
    local mod_ids="$1"
    
    echo "========================================"
    echo "   CurseForge Batch Mod Downloader"
    echo "========================================"
    echo
    
    # Validate input
    if [[ -z "$API_KEY" ]]; then
        log "ERROR" "HYTALE_CURSEFORGE_API_KEY environment variable not set"
        exit 1
    fi
    
    if [[ -z "$mod_ids" ]]; then
        log "ERROR" "Usage: $0 <mod_id1,mod_id2,...>"
        echo "Example: $0 1430860,1445747"
        exit 1
    fi
    
    log "INFO" "API Key configured (${#API_KEY} chars)"
    
    check_dependencies
    
    # Create destination directory
    mkdir -p "$DEST_DIR"
    log "INFO" "Destination: $DEST_DIR"
    
    # Fetch and download mods using batch API
    fetch_mods_batch "$mod_ids"
    
    log "OK" "All downloads completed!"
}

# Legacy function for compatibility with orchestrator
function download_mods_curseforge() {
    main "$1"
}

# Export function for use by orchestrator
export -f download_mods_curseforge

# Run if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    main "$1"
fi
