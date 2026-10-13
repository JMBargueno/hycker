#!/bin/bash
# download-server.sh
# Descarga y extrae los archivos del servidor de Hytale.
#
# Variables de entorno:
#   HYTALE_AUTO_UPDATE   true/false (por defecto false). Actualiza el servidor si hay versión nueva.
#   HYTALE_PATCHLINE     Opcional. Canal a usar (p. ej. pre-release). Por defecto, el release normal.
#   HYTALE_WAIT_FOR_AUTH true/false (por defecto false). Sin credenciales guardadas, espera al
#                        login OAuth2 aunque el server ya exista (la URL y el código salen en los logs).
#
# IMPORTANTE: el downloader guarda sus credenciales en .hytale-downloader-credentials.json
# y las REESCRIBE cuando se refrescan. Ese fichero debe vivir en un volumen persistente
# y con permisos de escritura (no montado como solo lectura).
# Añádelo también a .gitignore.

DOWNLOADER="./hytale-downloader-linux-amd64"
VERSION_FILE=".hytale-server-version"
SERVER_JAR="Server/HytaleServer.jar"
CREDENTIALS_FILE=".hytale-downloader-credentials.json"
ZIP_PATH=".hytale-server-download.zip"
PATCHLINE="${HYTALE_PATCHLINE:-}"

# Ejecuta el downloader con las opciones comunes.
# -skip-update-check evita la comprobación automática de actualizaciones del propio downloader
# (recomendado para automatización).
run_downloader() {
    local args=(-skip-update-check)
    if [ -n "$PATCHLINE" ]; then
        args+=(-patchline "$PATCHLINE")
    fi
    "$DOWNLOADER" "${args[@]}" "$@"
}

# Devuelve la versión del JUEGO disponible en remoto (vacío si falla).
# Los errores no se ocultan: se avisa por stderr.
get_remote_version() {
    local output version
    # '|| true': el entrypoint usa 'set -e'; un fallo aquí debe llegar al aviso, no abortar el script.
    output=$(run_downloader -print-version 2>&1) || true
    version=$(echo "$output" | grep -Eo '[0-9]{4}\.[0-9]{2}\.[0-9]{2}-[a-z0-9]+' | head -1)
    if [ -z "$version" ]; then
        echo -e "\033[1;33m[HYCKER] WARNING: could not determine remote version (auth or network issue?).\033[0m" >&2
        echo "[HYCKER] Downloader output: $output" >&2
    fi
    echo "$version"
}

ensure_downloader() {
    if [ ! -f "$DOWNLOADER" ]; then
        echo "[HYCKER] Downloading Hytale Downloader..."
        wget -O hytale-downloader.zip https://downloader.hytale.com/hytale-downloader.zip || {
            echo "[HYCKER] ERROR: could not download the Hytale Downloader."
            exit 1
        }
        unzip -q -o hytale-downloader.zip || {
            echo "[HYCKER] ERROR: could not extract the Hytale Downloader."
            exit 1
        }
        rm -f hytale-downloader.zip
        chmod +x "$DOWNLOADER"
    fi
}

download_and_extract_server() {
    local AUTO_UPDATE="${HYTALE_AUTO_UPDATE:-false}"
    local NEED_UPDATE=false
    local LOCAL_VERSION=""
    local REMOTE_VERSION=""

    # Versión instalada
    if [ -f "$VERSION_FILE" ]; then
        LOCAL_VERSION=$(cat "$VERSION_FILE")
    fi

    # Versión remota (solo si el downloader ya existe)
    if [ -f "$DOWNLOADER" ]; then
        REMOTE_VERSION=$(get_remote_version)
    fi

    # Aviso en amarillo si hay una versión nueva
    if [ -n "$REMOTE_VERSION" ] && [ "$LOCAL_VERSION" != "$REMOTE_VERSION" ]; then
        echo -e "\033[1;33m[HYCKER] New Hytale version available! Local: ${LOCAL_VERSION:-none}, Remote: $REMOTE_VERSION\033[0m"
        if [ "$AUTO_UPDATE" = "true" ]; then
            NEED_UPDATE=true
        fi
    fi

    # Si el server no existe, hay que descargar sí o sí
    local SERVER_MISSING=false
    if [ ! -f "$SERVER_JAR" ]; then
        SERVER_MISSING=true
        NEED_UPDATE=true
    fi

    if [ "$NEED_UPDATE" != true ]; then
        return 0
    fi

    # Sin credenciales guardadas, el downloader pedirá un login (URL + código).
    # - Si el server ya existe y no se ha pedido esperar el login, se salta la actualización
    #   en lugar de bloquear el arranque.
    # - Con HYTALE_WAIT_FOR_AUTH=true se espera al login (útil sin terminal: lee la URL y el
    #   código con 'docker logs -f').
    if [ ! -f "$CREDENTIALS_FILE" ]; then
        if [ "$SERVER_MISSING" = false ] && [ "${HYTALE_WAIT_FOR_AUTH:-false}" != "true" ]; then
            echo -e "\033[1;33m[HYCKER] WARNING: update skipped. No saved credentials ($CREDENTIALS_FILE).\033[0m"
            echo "[HYCKER] Authenticate once (docker run -it) or set HYTALE_WAIT_FOR_AUTH=true and check the logs for the login URL and code."
            return 0
        fi
        echo -e "\033[1;33m[HYCKER] No saved credentials. Open the URL and enter the code shown below to authenticate.\033[0m"
    fi

    echo "[HYCKER] =========================================="
    if [ "$SERVER_MISSING" = false ]; then
        echo "[HYCKER] Server files found, but a new version is available. Updating to latest release..."
    else
        echo "[HYCKER] Server files not found."
    fi
    echo "[HYCKER] Launching Hytale Downloader..."
    echo "[HYCKER] =========================================="
    echo ""

    ensure_downloader

    echo "[HYCKER] You will need to authenticate via OAuth2 (unless credentials are already saved)."
    echo "[HYCKER] Open the URL shown below and enter the authorization code."
    echo ""

    # Ruta de descarga explícita: no hace falta adivinar qué ZIP es el nuevo.
    rm -f "$ZIP_PATH"

    run_downloader -download-path "$ZIP_PATH" || {
        echo ""
        echo "[HYCKER] ERROR: the downloader failed."
        echo "[HYCKER] If it is an authentication error (401, expired token), delete $CREDENTIALS_FILE and run again."
        echo "[HYCKER] If it is a 404, check the patchline name and your account access."
        exit 1
    }

    if [ ! -f "$ZIP_PATH" ]; then
        echo "[HYCKER] ERROR: the downloader finished but $ZIP_PATH was not created."
        exit 1
    fi

    echo ""
    echo "[HYCKER] Extracting downloaded file: $ZIP_PATH"
    if unzip -o -q "$ZIP_PATH" -d .; then
        rm -f "$ZIP_PATH"
        echo "[HYCKER] Files extracted successfully!"
    else
        echo "[HYCKER] ERROR: failed to extract $ZIP_PATH."
        exit 1
    fi

    # En una primera instalación REMOTE_VERSION estaba vacío (no había downloader ni credenciales):
    # lo consultamos ahora para registrar la versión y evitar avisos falsos en el siguiente arranque.
    if [ -z "$REMOTE_VERSION" ]; then
        REMOTE_VERSION=$(get_remote_version)
    fi
    if [ -n "$REMOTE_VERSION" ]; then
        echo "$REMOTE_VERSION" > "$VERSION_FILE"
    fi

    # Verificar que el JAR del servidor existe
    if [ ! -f "$SERVER_JAR" ]; then
        echo ""
        echo "[HYCKER] ERROR: $SERVER_JAR not found after download."
        echo "[HYCKER] Please try again or mount the files manually."
        exit 1
    fi
    echo ""
}

# Exportar la función (útil solo si el entrypoint la invoca desde un subproceso bash;
# si se hace `source download-server.sh` no hace falta, pero no molesta)
export -f download_and_extract_server