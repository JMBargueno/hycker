

#!/bin/bash
# Function to download a ZIP, extract it, and move its contents to data/mods

set -e

download_mod_zip() {
  local ZIP_URL="$1"
  local MODS_DIR="/hycker/mods"
  local TMP_DIR="/tmp/hycker_mod_zip"

  if [ -z "$ZIP_URL" ]; then
    echo "Usage: download_mod_zip <zip_url>"
    return 1
  fi

  # Detect and handle Google Drive URLs (file or folder)
  if [[ "$ZIP_URL" =~ drive\.google\.com ]]; then
    echo "[HYCKER] Detected Google Drive URL, checking type..."

    # Detect if it's a folder URL
    if [[ "$ZIP_URL" =~ /drive/folders/([a-zA-Z0-9_-]+) ]]; then
      local FOLDER_ID="${BASH_REMATCH[1]}"
      echo "[HYCKER] Google Drive folder detected. Folder ID: $FOLDER_ID"
      # Check for gdown
      if command -v gdown &> /dev/null; then
        echo "[HYCKER] Using gdown to download folder recursively..."
        mkdir -p "$MODS_DIR"
        if gdown --folder "https://drive.google.com/drive/folders/$FOLDER_ID" -O "$MODS_DIR" 2>&1; then
          echo "[HYCKER] Folder downloaded successfully to $MODS_DIR"
          return 0
        else
          echo "[HYCKER] ERROR: gdown failed to download the folder."
          return 1
        fi
      else
        echo "[HYCKER] ERROR: gdown is not installed. Please install it to download Google Drive folders."
        return 1
      fi
    fi

    # Extract file ID from various Google Drive file URL formats
    local FILE_ID=""
    if [[ "$ZIP_URL" =~ /file/d/([a-zA-Z0-9_-]+) ]]; then
      FILE_ID="${BASH_REMATCH[1]}"
    elif [[ "$ZIP_URL" =~ id=([a-zA-Z0-9_-]+) ]]; then
      FILE_ID="${BASH_REMATCH[1]}"
    fi

    if [ -z "$FILE_ID" ]; then
      echo "[HYCKER] ERROR: Could not extract file ID from Google Drive URL"
      return 1
    fi

    echo "[HYCKER] Google Drive File ID: $FILE_ID"
  fi

  mkdir -p "$MODS_DIR"
  rm -rf "$TMP_DIR"
  mkdir -p "$TMP_DIR"

  local ZIP_FILE="$TMP_DIR/mod.zip"

  # Download the ZIP
  echo "[HYCKER] Downloading from $ZIP_URL..."
  
  # Special handling for Google Drive
  if [ -n "$FILE_ID" ]; then
    echo "[HYCKER] Using Google Drive download method..."
    echo "[HYCKER] File ID: $FILE_ID"
    
    # Use gdown if available (best for Google Drive)
    if command -v gdown &> /dev/null; then
      echo "[HYCKER] Using gdown for Google Drive download..."
      if gdown "https://drive.google.com/uc?id=$FILE_ID" -O "$ZIP_FILE" --fuzzy 2>&1; then
        echo "[HYCKER] Download completed with gdown"
      else
        echo "[HYCKER] ERROR: gdown failed to download the file"
        echo "[HYCKER] Make sure the Google Drive file is shared publicly (Anyone with the link can view)"
        rm -rf "$TMP_DIR"
        return 1
      fi
    else
      echo "[HYCKER] ERROR: gdown is not installed"
      rm -rf "$TMP_DIR"
      return 1
    fi
  else
    # Standard download for non-Google Drive URLs
    if ! curl -fL "$ZIP_URL" -o "$ZIP_FILE"; then
      echo "[HYCKER] ERROR: Failed to download file from $ZIP_URL"
      rm -rf "$TMP_DIR"
      return 1
    fi
  fi

  # Check if file exists and has content
  if [ ! -s "$ZIP_FILE" ]; then
    echo "[HYCKER] ERROR: Downloaded file is empty"
    rm -rf "$TMP_DIR"
    return 1
  fi

  # Verify it's a valid ZIP file by checking magic bytes (PK)
  local MAGIC_BYTES=$(head -c 2 "$ZIP_FILE" | od -An -tx1 | tr -d ' ')
  if [ "$MAGIC_BYTES" != "504b" ]; then
    echo "[HYCKER] ERROR: Downloaded file is not a valid ZIP archive"
    echo "[HYCKER] File starts with: $MAGIC_BYTES (expected: 504b for ZIP)"
    echo "[HYCKER] First 200 bytes of downloaded file:"
    head -c 200 "$ZIP_FILE"
    echo ""
    echo "[HYCKER] HINT: Make sure the URL points to a direct ZIP download, not a webpage"
    rm -rf "$TMP_DIR"
    return 1
  fi

  # Extract the ZIP in the temporary directory
  echo "[HYCKER] Extracting ZIP file..."
  unzip -o "$ZIP_FILE" -d "$TMP_DIR/unzipped"

  # Special handling for Google Drive: check for nested ZIP
  if [ -n "$FILE_ID" ]; then
    echo "[HYCKER] Google Drive detected - checking for nested ZIP structure..."
    
    # Find the first ZIP file inside the extracted content
    local NESTED_ZIP=$(find "$TMP_DIR/unzipped" -type f -name "*.zip" | head -1)
    
    if [ -n "$NESTED_ZIP" ]; then
      echo "[HYCKER] Found nested ZIP: $(basename "$NESTED_ZIP")"
      echo "[HYCKER] Extracting nested ZIP (mods folder)..."
      
      # Create a temporary directory for the nested ZIP
      mkdir -p "$TMP_DIR/nested"
      unzip -o "$NESTED_ZIP" -d "$TMP_DIR/nested"
      
      # Move content from nested extraction to mods directory
      echo "[HYCKER] Copying mods to $MODS_DIR..."
      cp -rv "$TMP_DIR/nested"/* "$MODS_DIR"/ 2>&1 | head -20
    else
      echo "[HYCKER] No nested ZIP found, using direct extraction"
      # Copy all files from subdirectories to mods root
      echo "[HYCKER] Files found to copy:"
      find "$TMP_DIR/unzipped" -type f -print
      
      # Copy each file directly to mods directory (flattening structure)
      while IFS= read -r file; do
        cp -v "$file" "$MODS_DIR/$(basename "$file")"
      done < <(find "$TMP_DIR/unzipped" -type f)
    fi
  else
    # Non-Google Drive: direct copy
    echo "[HYCKER] Copying mods to $MODS_DIR..."
    while IFS= read -r file; do
      cp -v "$file" "$MODS_DIR/$(basename "$file")"
    done < <(find "$TMP_DIR/unzipped" -type f)
  fi

  # Clean up
  rm -rf "$TMP_DIR"

  echo "[HYCKER] Mod downloaded and copied to $MODS_DIR successfully"
}

# Export the function so it can be used by the entrypoint script
export -f download_mod_zip

# Allow the script to be executed directly
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  download_mod_zip "$1"
fi
