# Scripts Documentation

This folder contains bash scripts used by the Hycker Docker container to configure and run the Hytale server.

## Overview

These scripts are designed to be sourced by [../entrypoint.sh](../entrypoint.sh) and provide modular functionality for:

- Downloading and installing server files
- Configuring backup options
- Displaying startup information

## Scripts

---

### mods-downloader.sh

**Purpose**: Orchestrates all mod downloaders in `scripts/mods_downloaders`.

**Usage**:

```bash
source /opt/hycker-scripts/mods-downloader.sh
# Or run directly:
bash /opt/hycker-scripts/mods-downloader.sh
```

**Behavior**:

- Detects the following environment variables and calls the corresponding script:
  - `HYCKER_MODS_ZIP_URL` → `download-mods-from-zip-url.sh`
  - `HYCKER_MODS_GDRIVE_URL` → `download-mods-gdrive.sh`
  - `HYCKER_MODS_CURSEFORGE_IDS` → `download-mods-curseforge.sh`
- Each script is called only if its variable is set.
- Logs each action with a clear prefix.

---

#### mods_downloaders/download-mods-from-zip-url.sh

**Purpose**: Downloads a ZIP file from a direct URL, extracts it, and copies its contents into `data/mods`.

**Usage**:

```bash
bash scripts/mods_downloaders/download-mods-from-zip-url.sh <zip_url>
```

**Environment Variable**:

- `HYCKER_MODS_ZIP_URL` (used by the orchestrator)

**Features**:

- Downloads and extracts any public ZIP URL
- Flattens directory structure for clean mod installation
- All log messages use the `[HYCKER - ZIP DOWNLOADER]` prefix

---

#### mods_downloaders/download-mods-gdrive.sh

**Purpose**: Downloads all files from a Google Drive folder URL into `data/mods`.

**Usage**:

```bash
bash scripts/mods_downloaders/download-mods-gdrive.sh <gdrive_folder_url>
```

**Environment Variable**:

- `HYCKER_MODS_GDRIVE_URL` (used by the orchestrator)

**Features**:

- Uses `gdown` to download all files in a Google Drive folder
- Flattens directory structure for clean mod installation
- All log messages use the `[HYCKER - GDRIVE DOWNLOADER]` prefix

---

#### mods_downloaders/download-mods-curseforge.sh

**Purpose**: Downloads mods from CurseForge using batch API requests with intelligent version management.

**Usage**:

```bash
HYTALE_CURSEFORGE_API_KEY=your_key bash scripts/mods_downloaders/download-mods-curseforge.sh <mod_id1,mod_id2,...>
```

**Environment Variables**:

- `HYCKER_MODS_CURSEFORGE_IDS` (used by the orchestrator)
- `HYTALE_CURSEFORGE_API_KEY` (required for CurseForge API access)

**Features**:

- Uses the CurseForge batch API (`/v1/mods`) for efficient multi-mod downloads
- Intelligent version management:
  - **Skip existing**: If exact mod file already exists, skips download (green message)
  - **Auto-upgrade**: Detects newer versions and automatically upgrades, removing old version
  - **Prevent downgrade**: Keeps existing mod if it's newer than the download version
- Version extraction from filenames (supports formats: `1.2.3`, `v1.2.3`, etc.)
- Requires `jq` for JSON parsing
- Clean output without progress bars for Docker compatibility
- All log messages use the `[HYCKER - CurseForge Batch Mod Downloader]` prefix

**Version Comparison Logic**:

1. Extracts base mod name and version from filename
2. Searches for existing mods with matching base name
3. Compares versions using semantic version sort
4. Takes appropriate action (skip/upgrade/keep existing)
5. Removes old version only after successful download of new version

---

## Scripts

---

### download-server.sh

**Purpose**: Automates the download, update check, and installation of Hytale server files.

**Main Function**: `download_and_extract_server()`

**Workflow**:

1. Always checks if a new Hytale server version is available using the downloader tool.
2. If a new version is available, prints a yellow warning: `[HYCKER] New Hytale version available! Local: <local_version>, Remote: <remote_version>`
3. If the environment variable `HYTALE_AUTO_UPDATE` is set to `true`, or if the server is missing, automatically downloads and installs the latest version.
4. Downloads `hytale-downloader-linux-amd64` from `https://downloader.hytale.com/hytale-downloader.zip` if not present.
5. Extracts and sets execute permissions.
6. Runs the downloader (requires OAuth2 authentication).
7. Extracts the downloaded ZIP file.
8. Verifies the JAR was extracted successfully.

**Environment Variables**:

- `HYTALE_AUTO_UPDATE` - If `true`, automatically updates to the latest server version when available. If `false`, only prints a warning if a new version is detected.

**Dependencies**:

- `wget` - to download the downloader
- `unzip` - to extract files
- `find` - to locate the downloaded file

**Notes**:

- The downloader requires OAuth2 authentication on first run
- Credentials are saved in `.hytale-downloader-credentials.json`
- The script automatically searches for the first `.zip` file in the directory
- Always checks for updates and notifies the user in yellow if a new version is available, regardless of auto-update setting

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

All scripts are loaded in [../entrypoint.sh](../entrypoint.sh) using `source` or executed directly:

```bash
source /opt/hycker-scripts/download-server.sh
source /opt/hycker-scripts/backup-config.sh
source /opt/hycker-scripts/display-startup-info.sh
# Orchestrate mod downloads (auto-detects env vars):
bash /opt/hycker-scripts/mods-downloader.sh
```

- All log messages use the `[HYCKER]` or `[HYCKER - ... DOWNLOADER]` prefix
- Functions are exported for use in the entrypoint where needed
- `eval` is used to modify arrays by reference
- The mods-downloader orchestrates all mod download logic via environment variables
- Scripts in `mods_downloaders` can also be run standalone if needed
