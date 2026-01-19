#!/bin/bash
# download-server.sh
# Downloads and extracts Hytale server files

# This function checks if the server JAR exists, and if not, downloads and extracts it
# The downloader requires OAuth2 authentication

download_and_extract_server() {
    # Si HYTALE_AUTO_UPDATE está en true, o el server no existe, forzar descarga
    AUTO_UPDATE=${HYTALE_AUTO_UPDATE:-false}
    NEED_UPDATE=false
    LOCAL_VERSION=""
    REMOTE_VERSION=""

    # Check installed version from file, and remote version from downloader
    VERSION_FILE=".hytale-server-version"
    if [ -f "$VERSION_FILE" ]; then
        LOCAL_VERSION=$(cat "$VERSION_FILE")
    fi
    if [ -f "hytale-downloader-linux-amd64" ]; then
        REMOTE_VERSION=$(./hytale-downloader-linux-amd64 -check-update 2>/dev/null | grep -Eo '[0-9]{4}\.[0-9]{2}\.[0-9]{2}-[a-z0-9]+')
    fi

    # Si hay una versión remota y es distinta a la local, avisar en amarillo
    if [ -n "$REMOTE_VERSION" ] && [ "$LOCAL_VERSION" != "$REMOTE_VERSION" ]; then
        # Yellow: \033[1;33m ... \033[0m
        echo -e "\033[1;33m[HYCKER] New Hytale version available! Local: $LOCAL_VERSION, Remote: $REMOTE_VERSION\033[0m"
        if [ "$AUTO_UPDATE" = "true" ]; then
            NEED_UPDATE=true
        fi
    fi

    # Si el server no existe, necesitamos descargar
    if [ ! -f "Server/HytaleServer.jar" ]; then
        NEED_UPDATE=true
    fi

    if [ "$NEED_UPDATE" = true ]; then
        echo "[HYCKER] =========================================="
        if [ -f "Server/HytaleServer.jar" ] && [ -n "$REMOTE_VERSION" ] && [ "$LOCAL_VERSION" != "$REMOTE_VERSION" ]; then
            echo "[HYCKER] Server files found, but a new version is available. Updating to latest release..."
        else
            echo "[HYCKER] Server files not found."
        fi
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
        

        # Ejecutar el downloader para obtener los archivos del servidor
        ./hytale-downloader-linux-amd64
        
        # Find the first ZIP file downloaded (usually contains server files)
        ZIP_FILE=$(find . -maxdepth 1 -name "*.zip" -type f | head -1)
        
        # If a ZIP file was downloaded, extract it and clean up
        if [ -n "$ZIP_FILE" ]; then
            echo ""
            echo "[HYCKER] Extracting downloaded file: $ZIP_FILE"
            # Extract quietly (-q flag) to current directory (-d .)
            unzip -o -q "$ZIP_FILE" -d .
            # Remove the ZIP file after extraction to save space
            rm -f "$ZIP_FILE"
            echo "[HYCKER] Files extracted successfully!"
            # Save the installed version to file if available
            if [ -n "$REMOTE_VERSION" ]; then
                echo "$REMOTE_VERSION" > "$VERSION_FILE"
            fi
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
