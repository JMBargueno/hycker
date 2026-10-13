<div align="center">

# 📜 Hycker Scripts Documentation

**Modular Bash Scripts for Automated Hytale Server Management**

</div>

---

## 📋 Overview

This directory contains the core automation scripts that power Hycker's features. Each script is designed to be sourced by [../entrypoint.sh](../entrypoint.sh) and provides modular functionality for server lifecycle management.

**Key Capabilities:**

- 🔄 Automated server downloads and version management
- 🧩 Multi-source mod installation
- 💾 Configurable backup orchestration
- 📊 Startup information display
- 🎯 Intelligent version control

---

## 🗂️ Script Structure

```
scripts/
├── download-server.sh                  # OAuth2 server download & version checking
├── backup-config.sh                    # Backup argument configuration
├── display-startup-info.sh             # Pre-launch configuration display
├── mods-downloader.sh                  # Mod download orchestrator
└── mods_downloaders/
    ├── download-mods-from-zip-url.sh   # Direct ZIP downloads
    ├── download-mods-gdrive.sh         # Google Drive integration
    └── download-mods-curseforge.sh     # CurseForge API client
```

---

## 🔧 Core Scripts

### 📥 download-server.sh

**Purpose**: Automated Hytale server download, update detection, and installation.

**Main Function**: `download_and_extract_server()`

**Features:**

- ✅ Automatic game version check on every startup (`-print-version`)
- 🔔 Visual warnings when new versions are detected
- 🔄 Optional auto-update via `HYTALE_AUTO_UPDATE=true`
- 🔐 OAuth2 authentication with credential caching (`.hytale-downloader-credentials.json`)
- 📦 Download to an explicit path (`-download-path`), ZIP extraction and validation
- 🛡️ Fails loudly: downloader, `wget` and `unzip` errors stop the startup with a clear message
- 🚫 Never blocks an already-installed server waiting for a login (unless you ask it to)
- 🧪 Optional patchline selection via `HYTALE_PATCHLINE`

**Workflow:**

1. Read the local version from the `.hytale-server-version` file
2. If the downloader binary exists, query the remote **game** version with `hytale-downloader-linux-amd64 -print-version`
3. Compare versions and display a warning if the server is outdated
4. Mark an update as needed if `HYTALE_AUTO_UPDATE=true` and a newer version exists, or if `Server/HytaleServer.jar` is missing
5. If no saved credentials exist and the server is already installed, skip the update with a warning (unless `HYTALE_WAIT_FOR_AUTH=true`)
6. Download the downloader if needed, then run it with `-download-path .hytale-server-download.zip` (exit with an error if it fails)
7. Extract the ZIP and remove it
8. Save the new version to the tracking file (on a first install, the version is queried after the download)
9. Validate that `Server/HytaleServer.jar` exists

> ℹ️ The downloader's `-check-update` flag checks for updates of the **downloader itself**, not of the game server, so this script does not use it. All downloader calls use `-skip-update-check` to avoid the automatic self-update check on every startup.

**Environment Variables:**

| Variable               | Description                                                                                                                      | Default            |
| ---------------------- | -------------------------------------------------------------------------------------------------------------------------------- | ------------------ |
| `HYTALE_AUTO_UPDATE`   | Automatically download the latest server version                                                                                 | `false`            |
| `HYTALE_PATCHLINE`     | Release channel to use (e.g. `pre-release`)                                                                                      | _(normal release)_ |
| `HYTALE_WAIT_FOR_AUTH` | With no saved credentials and the server already installed, wait for the OAuth2 login instead of skipping the update (see below) | `false`            |

**Dependencies:**

- `wget` - Downloader retrieval
- `unzip` - Archive extraction

#### 🔐 Authentication & Credentials

The downloader uses an OAuth2 device-code login: it prints a URL and an authorization code, and you open the URL in any browser (your PC or phone, not necessarily the server).

- Credentials are stored in `.hytale-downloader-credentials.json`
- The downloader **rewrites this file whenever the token is refreshed**, so it must live in a **persistent, writable volume** (not mounted read-only)
- If the file is lost, you will need to log in again
- Add it to `.gitignore` if the directory is under Git

**Recommended setup (log in once, then everything is automatic):**

```yaml
# docker-compose.yml (excerpt)
services:
  hytale:
    volumes:
      - ./data:/hycker # keeps .hytale-downloader-credentials.json between restarts
```

```bash
# First run only: authenticate interactively
docker compose run --rm -it hytale
```

**Without a terminal** (hosting panels, orchestrators): start with `HYTALE_WAIT_FOR_AUTH=true`, read the login URL and code from `docker logs -f`, and complete the login. The credentials are then saved for later restarts.

**Behavior when credentials are missing:**

| Situation                                      | Behavior                                                    |
| ---------------------------------------------- | ----------------------------------------------------------- |
| Server not installed (first install)           | Proceeds with the download and shows the login URL and code |
| Server installed, `HYTALE_WAIT_FOR_AUTH=false` | Skips the update with a warning, server starts normally     |
| Server installed, `HYTALE_WAIT_FOR_AUTH=true`  | Waits for the login, then updates                           |

> ⚠️ If a login code expires before you authenticate, the downloader fails and the script exits with an error. With `restart: unless-stopped`, the container will loop requesting new codes until you complete the login.

**Troubleshooting:**

| Problem                              | Solution                                                                          |
| ------------------------------------ | --------------------------------------------------------------------------------- |
| Authentication error / 401           | Delete `.hytale-downloader-credentials.json` and run again                        |
| Device code expired                  | Restart to get a new authorization code                                           |
| Checksum mismatch                    | Retry the download                                                                |
| 404 Not Found                        | Check the patchline name (`HYTALE_PATCHLINE`) and your access                     |
| "could not determine remote version" | Check network and credentials; the downloader output is printed below the warning |

**Example Output:**

```bash
[HYCKER] New Hytale version available! Local: 2026.01.15-abc123, Remote: 2026.02.03-def456
[HYCKER] Server files found, but a new version is available. Updating to latest release...
[HYCKER] Launching Hytale Downloader...
[HYCKER] Extracting downloaded file: .hytale-server-download.zip
[HYCKER] Files extracted successfully!
```

**Example Output (update skipped, no saved credentials):**

```bash
[HYCKER] New Hytale version available! Local: 2026.01.15-abc123, Remote: 2026.02.03-def456
[HYCKER] WARNING: update skipped. No saved credentials (.hytale-downloader-credentials.json).
[HYCKER] Authenticate once (docker run -it) or set HYTALE_WAIT_FOR_AUTH=true and check the logs for the login URL and code.
```

---

### 💾 backup-config.sh

**Purpose**: Configures server backup arguments based on environment variables.

**Main Function**: `configure_backup_options(java_args_ref)`

**Parameters:**

- `java_args_ref` - Reference to Java arguments array (modified via `eval`)

**Configuration Logic:**

```bash
if HYTALE_BACKUP_ENABLED=true:
    Add: --backup
    Add: --backup-dir <path>      (if HYTALE_BACKUP_DIR set)
    Add: --backup-frequency <min>  (if HYTALE_BACKUP_FREQUENCY set)
```

**Environment Variables:**

| Variable                  | Description               | Default           |
| ------------------------- | ------------------------- | ----------------- |
| `HYTALE_BACKUP_ENABLED`   | Enable/disable backups    | `true`            |
| `HYTALE_BACKUP_DIR`       | Backup storage directory  | `/hycker/backups` |
| `HYTALE_BACKUP_FREQUENCY` | Backup interval (minutes) | `30`              |

**Usage Example:**

```bash
declare -a java_args=(java -jar HytaleServer.jar)
configure_backup_options java_args
# Result: java_args now includes backup flags
```

**Color Indicators:**

- 🟢 Green: Backup enabled with configuration
- 🔴 Red: Backup disabled

---

### 📊 display-startup-info.sh

**Purpose**: Displays comprehensive server configuration before launch.

**Main Function**: `display_startup_info(server_jar, assets_path, java_args_ref)`

**Displayed Information:**

| Item          | Source                     |
| ------------- | -------------------------- |
| JAR Path      | `$server_jar` parameter    |
| Assets Path   | `$assets_path` parameter   |
| Bind Address  | `${HYTALE_BIND_ADDRESS}`   |
| Auth Mode     | `${HYTALE_AUTH_MODE}`      |
| Backup Status | `${HYTALE_BACKUP_ENABLED}` |
| Java Options  | `${JAVA_OPTS}`             |
| Full Command  | Complete `java_args` array |

**Example Output:**

```bash
[HYCKER] Starting Hytale server with configuration:
[HYCKER] JAR: Server/HytaleServer.jar
[HYCKER] Assets: Assets.zip
[HYCKER] Bind Address: 0.0.0.0:5520
[HYCKER] Auth Mode: authenticated
[HYCKER] Backup Enabled: true
[HYCKER] Java Options: -Xms1G -Xmx4G

[HYCKER] Java command to execute:
[HYCKER] java -Xms1G -Xmx4G -jar Server/HytaleServer.jar --assets Assets.zip --bind 0.0.0.0:5520 --auth-mode authenticated --backup --backup-dir /hycker/backups --backup-frequency 30
```

---

## 🧩 Mod Management System

### 🎯 mods-downloader.sh

**Purpose**: Orchestrator that coordinates all mod download sources.

**Detection Logic:**

```bash
if HYCKER_MODS_ZIP_URL set        → Call download-mods-from-zip-url.sh
if HYCKER_MODS_GDRIVE_URL set     → Call download-mods-gdrive.sh
if HYCKER_MODS_CURSEFORGE_IDS set → Call download-mods-curseforge.sh
```

**Features:**

- ✅ Environment variable auto-detection
- 🔀 Sequential multi-source processing
- 📝 Consistent logging prefixes
- 🛡️ Error handling with fallback to server startup

**Usage:**

```bash
# Sourced by entrypoint.sh
source /opt/hycker-scripts/mods-downloader.sh

# Or direct execution
bash /opt/hycker-scripts/mods-downloader.sh
```

#### 📦 download-mods-from-zip-url.sh

**Purpose**: Downloads and extracts mods from direct ZIP URLs.

**Function**: `download_mods_from_zip_url(zip_url)`

**Process Flow:**

1. Create temporary directory
2. Download ZIP using `curl -L`
3. Extract to temp location
4. Flatten directory structure
5. Copy all files (except `.zip`) to `/hycker/mods`
6. Cleanup temporary files

**Environment Variable:**

- `HYCKER_MODS_ZIP_URL` - Direct URL to ZIP file

**Command-Line Usage:**

```bash
bash download-mods-from-zip-url.sh "https://example.com/mods.zip"
```

**Example Output:**

```
[HYCKER - ZIP DOWNLOADER] Downloading ZIP from https://example.com/mods.zip ...
[HYCKER - ZIP DOWNLOADER] Files extracted to /hycker/mods
```

#### 🌐 download-mods-gdrive.sh

**Purpose**: Bulk download from Google Drive shared folders.

**Function**: `download_mods_gdrive(gdrive_folder_url)`

**Process Flow:**

1. Check for `gdown` installation (auto-install via pip)
2. Download entire folder using `gdown --folder`
3. Flatten directory structure
4. Copy all files to `/hycker/mods`
5. Cleanup temporary files

**Environment Variable:**

- `HYCKER_MODS_GDRIVE_URL` - Google Drive folder URL

**Requirements:**

- Python 3 with pip
- `gdown` package (auto-installed)

**Command-Line Usage:**

```bash
bash download-mods-gdrive.sh "https://drive.google.com/drive/folders/1A2B3C4D5E"
```

**Example Output:**

```
[HYCKER - GDRIVE DOWNLOADER] Downloading all files from Google Drive folder...
[HYCKER - GDRIVE DOWNLOADER] Files downloaded to /hycker/mods
```

#### 🔥 download-mods-curseforge.sh

**Purpose**: Intelligent CurseForge mod downloads with version management.

**Function**: `download_mods_curseforge(mod_ids)`

**Advanced Features:**

#### 🎯 Batch API Requests

- Uses `/v1/mods` POST endpoint for efficient multi-mod queries
- Single API call for multiple mods
- Reduced API rate limit impact

#### 🧠 Intelligent Version Management

| Scenario      | Action                            | Message Color |
| ------------- | --------------------------------- | ------------- |
| Exact match   | Skip download                     | 🟢 Green      |
| Older version | Download new + delete old         | 🔵 Blue       |
| Newer version | Keep existing (prevent downgrade) | 🟡 Yellow     |
| Same version  | Skip download                     | 🟢 Green      |

#### 📊 Version Comparison

```bash
# Supported formats:
mod-1.2.3.jar
mod-v1.2.3.jar
awesome-mod-2.1.jar
plugin_1.0.0-beta.jar

# Extraction pattern:
(?:v)?[0-9]+\.[0-9]+(?:\.[0-9]+)?
```

**Environment Variables:**

| Variable                     | Required | Description             |
| ---------------------------- | -------- | ----------------------- |
| `HYCKER_MODS_CURSEFORGE_IDS` | Yes      | Comma-separated mod IDs |
| `HYTALE_CURSEFORGE_API_KEY`  | No       | CurseForge API key      |

**Dependencies:**

- `curl` - API requests
- `jq` - JSON parsing (auto-installed)

**Command-Line Usage:**

```bash
HYTALE_CURSEFORGE_API_KEY="your_key" \
bash download-mods-curseforge.sh "1423494,1409811"
```

**Example Output:**

```
========================================
   CurseForge Batch Mod Downloader
========================================

[HYCKER - CurseForge Batch Mod Downloader - INFO] Making batch API request for mod IDs: [1423494,1409811]
[HYCKER - CurseForge Batch Mod Downloader - OK] Batch API request successful
[HYCKER - CurseForge Batch Mod Downloader - INFO] Processing: Awesome Mod (ID: 1423494)
[HYCKER - CurseForge Batch Mod Downloader - INFO] Found older version: awesome-mod-1.0.0.jar (v1.0.0) -> upgrading to v1.1.0
[HYCKER - CurseForge Batch Mod Downloader - OK] Downloaded 'Awesome Mod' -> awesome-mod-1.1.0.jar
[HYCKER - CurseForge Batch Mod Downloader - INFO] Removing old version: awesome-mod-1.0.0.jar
[HYCKER - CurseForge Batch Mod Downloader - OK] Upgrade complete
[HYCKER - CurseForge Batch Mod Downloader - OK] All downloads completed!
```

**Error Handling:**

- Invalid mod IDs (non-numeric) are skipped with warnings
- HTTP errors display status codes and response bodies
- Missing download URLs trigger error messages
- Failed downloads don't interrupt batch processing

---

## 🔗 Integration Architecture

### Entrypoint Integration

All scripts are loaded by [../entrypoint.sh](../entrypoint.sh):

```bash
#!/bin/bash
set -e

# Source utility scripts
source /opt/hycker-scripts/download-server.sh
source /opt/hycker-scripts/backup-config.sh
source /opt/hycker-scripts/display-startup-info.sh
source /opt/hycker-scripts/mods-downloader.sh

cd /hycker

# Orchestrate mod downloads
if [ -n "$HYCKER_MODS_ZIP_URL" ] || [ -n "$HYCKER_MODS_GDRIVE_URL" ] || [ -n "$HYCKER_MODS_CURSEFORGE_IDS" ]; then
    mods_downloader_main
fi

# Download server if needed
download_and_extract_server

# Build Java command
declare -a java_args=(java ${JAVA_OPTS} -jar "$SERVER_JAR" --assets "$ASSETS_PATH")
configure_backup_options java_args
display_startup_info "$SERVER_JAR" "$ASSETS_PATH" java_args

# Start server
exec "${java_args[@]}"
```

### Function Exports

All main functions are exported for cross-script usage:

```bash
export -f download_and_extract_server
export -f configure_backup_options
export -f display_startup_info
export -f download_mods_from_zip_url
export -f download_mods_gdrive
export -f download_mods_curseforge
```

---

## 🎨 Logging Standards

All scripts follow consistent logging patterns:

| Prefix                                       | Purpose                    |
| -------------------------------------------- | -------------------------- |
| `[HYCKER]`                                   | General container messages |
| `[HYCKER - ZIP DOWNLOADER]`                  | ZIP download operations    |
| `[HYCKER - GDRIVE DOWNLOADER]`               | Google Drive operations    |
| `[HYCKER - CurseForge Batch Mod Downloader]` | CurseForge operations      |

**Color Coding:**

- 🔵 Blue (`\033[0;34m`) - Informational messages
- 🟢 Green (`\033[0;32m`) - Success/OK operations
- 🟡 Yellow (`\033[1;33m`) - Warnings
- 🔴 Red (`\033[0;31m`) - Errors
- ⚪ Reset (`\033[0m`) - Normal text

---

## 🛠️ Development Guidelines

### Adding New Scripts

1. Create script in `/scripts/` or `/scripts/mods_downloaders/`
2. Add shebang: `#!/bin/bash`
3. Use `set -e` for error handling
4. Export main function with `export -f`
5. Add to `entrypoint.sh` sourcing
6. Document in this file

### Testing Scripts

```bash
# Server download script (defines a function, so source it and call it)
bash -c 'source scripts/download-server.sh && download_and_extract_server'

# Mod downloader testing
HYCKER_MODS_ZIP_URL="https://example.com/mods.zip" \
bash scripts/mods_downloaders/download-mods-from-zip-url.sh

# Full integration testing
docker-compose -f docker-compose.dev.yml up --build
```

---

## 📝 Script Reference Table

| Script                          | Type         | Exports Function | Used By         |
| ------------------------------- | ------------ | ---------------- | --------------- |
| `download-server.sh`            | Core         | ✅ Yes           | entrypoint.sh   |
| `backup-config.sh`              | Core         | ✅ Yes           | entrypoint.sh   |
| `display-startup-info.sh`       | Core         | ✅ Yes           | entrypoint.sh   |
| `mods-downloader.sh`            | Orchestrator | ✅ Yes           | entrypoint.sh   |
| `download-mods-from-zip-url.sh` | Mod Loader   | ✅ Yes           | mods-downloader |
| `download-mods-gdrive.sh`       | Mod Loader   | ✅ Yes           | mods-downloader |
| `download-mods-curseforge.sh`   | Mod Loader   | ✅ Yes           | mods-downloader |

---

<div align="center">

**🔗 Related Documentation**

[Main README](../README.md) • [Entrypoint Script](../entrypoint.sh) • [Docker Compose](../docker-compose.yml)

</div>
