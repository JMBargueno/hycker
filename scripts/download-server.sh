#!/bin/bash
# download-server.sh
# Downloads and extracts Hytale server files

# This function checks if the server JAR exists, and if not, downloads and extracts it
# The downloader requires OAuth2 authentication

download_and_extract_server() {
    # Check if the Hytale server JAR file exists, if not download it
    if [ ! -f "Server/HytaleServer.jar" ]; then
        echo "[HYCKER] =========================================="
        echo "[HYCKER] Server files not found."
        echo "[HYCKER] Launching Hytale Downloader..."
        echo "[HYCKER] =========================================="
        echo ""
        
        # Download the Hytale downloader if it doesn't exist
        if [ ! -f "hytale-downloader-linux-amd64" ]; then
            echo "[HYCKER] Downloading Hytale Downloader..."
            wget -O hytale-downloader.zip https://downloader.hytale.com/hytale-downloader.zip
            unzip -q hytale-downloader.zip
            rm -f hytale-downloader.zip
            chmod +x hytale-downloader-linux-amd64
        fi
        
        echo "[HYCKER] You will need to authenticate via OAuth2."
        echo "[HYCKER] Follow the instructions displayed by the downloader."
        echo ""
        
        # Execute the Hytale downloader to fetch server files
        # The downloader is in the current working directory
        ./hytale-downloader-linux-amd64
        
        # Find the first ZIP file downloaded (usually contains server files)
        ZIP_FILE=$(find . -maxdepth 1 -name "*.zip" -type f | head -1)
        
        # If a ZIP file was downloaded, extract it and clean up
        if [ -n "$ZIP_FILE" ]; then
            echo ""
            echo "[HYCKER] Extracting downloaded file: $ZIP_FILE"
            # Extract quietly (-q flag) to current directory (-d .)
            unzip -q "$ZIP_FILE" -d .
            # Remove the ZIP file after extraction to save space
            rm -f "$ZIP_FILE"
            echo "[HYCKER] Files extracted successfully!"
        fi
        
        # Verify that the server JAR file was extracted successfully
        if [ ! -f "Server/HytaleServer.jar" ]; then
            echo ""
            echo "[HYCKER] ERROR: Server/HytaleServer.jar not found after download."
            echo "[HYCKER] Please try again or mount the files manually."
            exit 1
        fi
        echo ""
    fi
}

# Export the function so it can be used by the entrypoint script
export -f download_and_extract_server
