# Scripts Documentation

This folder contains bash scripts used by the Hycker Docker container to configure and run the Hytale server.

## Overview

These scripts are designed to be sourced by [../entrypoint.sh](../entrypoint.sh) and provide modular functionality for:

- Downloading and installing server files
- Configuring backup options
- Displaying startup information

## Scripts

### download-mod-zip.sh

**Purpose**: Downloads a ZIP file from a URL, extracts it, and copies its contents into `data/mods`.

**Main Function**: `download_mod_zip <zip_url>`

**Usage**:

```bash
download_mod_zip "https://example.com/mod.zip"
```

**Details**:

- The destination is always `data/mods` relative to the project root.
- Uses a temporary directory in `/tmp` for download and extraction.

**Integration**:

- The script defines the function and can be used standalone or (recommended) as a sourced function.
- In `entrypoint.sh`, it is automatically called if the environment variable `HYCKER_MOD_ZIP_URL` is set:

```bash
source /opt/hycker-scripts/download-mod-zip.sh
if [ -n "$HYCKER_MOD_ZIP_URL" ]; then
  echo "[HYCKER] Downloading mod from $HYCKER_MOD_ZIP_URL"
  download_mod_zip "$HYCKER_MOD_ZIP_URL"
fi
```

**Dependencies**:

- `curl` to download the ZIP
- `unzip` to extract the file

---

### download-server.sh

**Purpose**: Automates the download and installation of Hytale server files.

**Main Function**: `download_and_extract_server()`

**Workflow**:

1. Checks if `Server/HytaleServer.jar` exists
2. If not found:
   - Downloads `hytale-downloader-linux-amd64` from `https://downloader.hytale.com/hytale-downloader.zip`
   - Extracts and sets execute permissions
   - Runs the downloader (requires OAuth2 authentication)
   - Extracts the downloaded ZIP file
   - Verifies the JAR was extracted successfully

**Dependencies**:

- `wget` - to download the downloader
- `unzip` - to extract files
- `find` - to locate the downloaded file

**Notes**:

- The downloader requires OAuth2 authentication on first run
- Credentials are saved in `.hytale-downloader-credentials.json`
- The script automatically searches for the first `.zip` file in the directory

---

### backup-config.sh

**Purpose**: Configures Hytale server backup options based on environment variables.

**Main Function**: `configure_backup_options(java_args_ref)`

**Parameters**:

- `java_args_ref`: Reference to the Java arguments array (modified by reference using `eval`)

**Environment Variables**:

- `HYTALE_BACKUP_ENABLED` - Enable/disable backups (true/false)
- `HYTALE_BACKUP_DIR` - Directory where backups are stored
- `HYTALE_BACKUP_FREQUENCY` - Backup frequency in minutes

**Behavior**:

- If `HYTALE_BACKUP_ENABLED=true`:
  - Adds `--backup` to Java arguments
  - Adds `--backup-dir` if defined
  - Adds `--backup-frequency` if defined
- If disabled, displays a red message

**Usage Example**:

```bash
declare -a java_args=(java -jar server.jar)
configure_backup_options java_args
# Result: java_args contains backup arguments
```

---

### display-startup-info.sh

**Purpose**: Displays configuration information before starting the server.

**Main Function**: `display_startup_info(server_jar, assets_path, java_args_ref)`

**Parameters**:

- `server_jar`: Path to the server JAR file
- `assets_path`: Path to the Assets.zip file
- `java_args_ref`: Reference to the Java arguments array

**Information Displayed**:

- Server JAR path
- Assets path
- Bind address (default: `0.0.0.0:5520`)
- Authentication mode
- Backup status
- Java options (`JAVA_OPTS`)
- Complete Java command to be executed

**Colors**:

- Green (`\033[0;32m`) - Configuration information
- Yellow (`\033[0;33m`) - Command to execute
- Reset (`\033[0m`) - Restore normal color

---

## Integration with entrypoint.sh

All three scripts are loaded in [../entrypoint.sh](../entrypoint.sh) using `source`:

```bash
source /opt/hycker-scripts/download-server.sh
source /opt/hycker-scripts/backup-config.sh
source /opt/hycker-scripts/display-startup-info.sh
source /opt/hycker-scripts/download-mod-zip.sh
```

They are then executed in this order:

1. `download_mod_zip` - Downloads and extracts mods if `HYCKER_MOD_ZIP_URL` is set
2. `download_and_extract_server` - Ensures server files exist
3. `configure_backup_options` - Configures backup arguments
4. `display_startup_info` - Shows final configuration
5. `exec "${java_args[@]}"` - Starts the server

## Modifications and Extensions

To add new functionality:

1. Create a new script in `scripts/`
2. Export functions with `export -f function_name`
3. Source the script in [../entrypoint.sh](../entrypoint.sh)
4. Call the function at the appropriate point in the flow

## Conventions

- All log messages use the `[HYCKER]` prefix
- Functions are exported for use in the entrypoint
- `eval` is used to modify arrays by reference
- Scripts have no direct execution logic (only define functions)
