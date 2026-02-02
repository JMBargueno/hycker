<div align="center">
  <img src="assets/hycker_logo.png" alt="Hycker Logo" width="400"/>
</div>

# Hycker - Hytale Server Docker Container

A Docker container for running a Hytale game server with automated setup, backup support, and easy configuration through environment variables.

## 🚀 Quick Start

1. Clone this repository
2. Run the container:
   ```bash
   docker-compose up -d
   ```
3. On first run, follow the OAuth2 authentication prompts to download server files
4. The server will start automatically once files are downloaded

## 📁 Project Structure

### Core Files

#### `Dockerfile`

Multi-stage Docker image based on `eclipse-temurin:25-jdk-jammy` that:

- Installs required dependencies (wget, unzip, curl)
- Sets up the `/hycker` working directory
- Copies and configures entrypoint and utility scripts
- Creates a non-root user `hytale` (UID 1000) for security
- Handles CRLF to LF line ending conversion for cross-platform compatibility
- Includes health checks to monitor server status

**Key Features**:

- Minimal dependencies to reduce image size
- Automatic line ending normalization for Windows/Linux compatibility
- Health check monitors Java process every 30 seconds
- Scripts copied to `/opt/hycker-scripts/` for organization.

#### `docker-compose.yml`

Defines the Hycker service with:

- **Port mapping**: `25573:5520/udp` (external:internal)
- **Volume mount**: `./data:/hycker` for persistent data
- **Restart policy**: `unless-stopped` for automatic recovery
- **Interactive mode**: `tty: true` and `stdin_open: true` for server console access

**Configuration**:

- All settings are configurable via environment variables
- Uses bridge networking mode
- Data persists in the local `./data` directory

#### `entrypoint.sh`

Main orchestration script that:

1. Displays Hycker ASCII banner and version information
2. Sources utility scripts from `/opt/hycker-scripts/`
3. Downloads server files if not present (via OAuth2)
4. Validates server JAR and Assets.zip existence
5. Builds Java command array with all configuration options
6. Displays complete startup information
7. Starts the Hytale server with `exec`

**Execution Flow**:

```
ASCII Banner → Source Scripts → Download Server Files → Validate Files →
Build Java Args → Configure Backups → Display Info → Start Server
```

### Utility Scripts

See [scripts/SCRIPTS.md](scripts/SCRIPTS.md) for detailed documentation of:

- `download-server.sh` - Server file download automation
- `backup-config.sh` - Backup configuration management
- `display-startup-info.sh` - Startup information display

## ⚙️ Environment Variables

| Variable                      | Description                                                                                                                                                                            | Default           | Example                                              |
| ----------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ----------------- | ---------------------------------------------------- |
| `HYTALE_ASSETS_PATH`          | Path to the Assets.zip file                                                                                                                                                            | `Assets.zip`      | `Assets.zip`                                         |
| `HYTALE_AUTH_MODE`            | Authentication mode for players                                                                                                                                                        | `authenticated`   | `authenticated` or `offline`                         |
| `HYTALE_BIND_ADDRESS`         | Server bind address and port                                                                                                                                                           | `0.0.0.0:5520`    | `0.0.0.0:5520`                                       |
| `HYTALE_BACKUP_ENABLED`       | Enable automatic backups                                                                                                                                                               | `true`            | `true` or `false`                                    |
| `HYTALE_BACKUP_FREQUENCY`     | Backup interval in minutes                                                                                                                                                             | `30`              | `30`, `60`, `120`                                    |
| `HYTALE_BACKUP_DIR`           | Directory for backup storage                                                                                                                                                           | `/hycker/backups` | `/hycker/backups`                                    |
| `HYTALE_DISABLE_SENTRY`       | Disable Sentry crash reporting                                                                                                                                                         | `false`           | `true` or `false`                                    |
| `JAVA_OPTS`                   | JVM memory and performance options                                                                                                                                                     | `-Xms1G -Xmx4G`   | `-Xms2G -Xmx8G`                                      |
| `HYTALE_AUTO_UPDATE`          | If `true`, automatically updates to the latest Hytale server version when available. If `false`, only prints a warning if a new version is detected.                                   | `false`           | `true` or `false`                                    |
| `HYCKER_MODS_ZIP_URL`         | URL of a mod ZIP to download and extract into `data/mods` before starting the server                                                                                                   | _(empty)_         | `https://example.com/mods.zip`                       |
| `HYCKER_MODS_GDRIVE_URL`      | Google Drive folder URL to download all mods from before starting the server                                                                                                           | _(empty)_         | `https://drive.google.com/drive/folders/<FOLDER_ID>` |
| `HYCKER_MODS_CURSEFORGE_IDS`  | Comma-separated list of CurseForge mod IDs to download before starting the server                                                                                                      | _(empty)_         | `12345,67890`                                        |
| `HYTALE_CURSEFORGE_API_KEY`   | API key for CurseForge API (required for CurseForge mod downloads)                                                                                                                     | _(empty)_         | `your-api-key`                                       |
| `HYTALE_ACCEPT_EARLY_PLUGINS` | If `true`, enables the `--accept-early-plugins` flag when starting the server. Prints a yellow warning: "[WARNING] --accept-early-plugins is enabled. Early plugins will be accepted!" | `false`           | `true`                                               |
| `HYTALE_ADDITIONAL_ARGS`      | Additional arguments to append to the Java command when starting the server. If set, these will be shown in yellow at startup. Useful for custom JVM or server flags.                  | _(empty)_         | `-Dfile.encoding=UTF-8`                              |

## ➕ Additional Java Arguments

If the environment variable `HYTALE_ADDITIONAL_ARGS` is set, its contents will be appended to the Java command when starting the server. The arguments will be displayed in yellow at startup for visibility. This is useful for passing custom JVM options or server flags.

Example:

```
HYTALE_ADDITIONAL_ARGS="-Dfile.encoding=UTF-8 -Duser.timezone=UTC"
```

This will add those options to the Java process that runs the Hytale server.

## 🧩 Early Plugins Acceptance

If the environment variable `HYTALE_ACCEPT_EARLY_PLUGINS` is set to `true`, the container will start the server with the `--accept-early-plugins` flag. This allows early plugins to be accepted by the server. A yellow warning will be printed at startup:

```
[WARNING] --accept-early-plugins is enabled. Early plugins will be accepted!
```

Use this option only if you understand the risks of accepting early plugins.

---

## 🔄 Automatic Update and Version Check

The container always checks if a new Hytale server version is available before starting. If a new version is detected, a yellow warning will be printed:

```
[HYCKER] New Hytale version available! Local: <local_version>, Remote: <remote_version>
```

If the environment variable `HYTALE_AUTO_UPDATE` is set to `true`, the latest version will be downloaded and installed automatically. If set to `false`, only the warning will be shown and the server will not update automatically.

This ensures you are always notified of new releases and can choose whether to update automatically or manually.

## 🧩 Automatic Mods Download

Hycker supports automatic mod installation from multiple sources using environment variables. The orchestrator script (`mods-downloader.sh`) will detect and process the following:

- `HYCKER_MODS_ZIP_URL`: Downloads and extracts a ZIP file from a direct URL or Google Drive file/folder into `data/mods`.
- `HYCKER_MODS_GDRIVE_URL`: Downloads all files from a Google Drive folder into `data/mods` (requires `gdown`).
- `HYCKER_MODS_CURSEFORGE_IDS`: Downloads mods from CurseForge by numeric mod IDs (requires `HYTALE_CURSEFORGE_API_KEY` and `jq`).

You can set one or more of these variables to automate mod installation. Each will be processed in order if set.

### Example Configuration

**docker-compose.yml**:

```yaml
environment:
  # Direct ZIP download
  HYCKER_MODS_ZIP_URL: "https://example.com/mods.zip"

  # Google Drive folder
  HYCKER_MODS_GDRIVE_URL: "https://drive.google.com/drive/folders/<FOLDER_ID>"

  # CurseForge mods by ID
  HYCKER_MODS_CURSEFORGE_IDS: "12345,67890"
  HYTALE_CURSEFORGE_API_KEY: "your-api-key"
```

### Features

- ✅ Automatic Google Drive detection and folder download
- ✅ Supports direct ZIP and Google Drive file/folder URLs
- ✅ Supports CurseForge mod downloads by ID (latest file)
- ✅ Flattens directory structure for clean mod installation
- ✅ Logs each action with a clear prefix

This allows you to automate the installation of custom mods from multiple sources on every deployment.

### Variable Details

**HYTALE_ASSETS_PATH**

- Points to the game assets archive
- Required for server startup
- Automatically searched in current and parent directories

**HYTALE_AUTH_MODE**

- `authenticated`: Requires valid Hytale accounts
- `offline`: Allows offline/cracked clients (not recommended for public servers)

**HYTALE_BIND_ADDRESS**

- Must be `0.0.0.0:5520` for Docker containers to accept external connections
- Port must match the internal port in docker-compose.yml

**HYTALE_BACKUP_ENABLED**

- When `true`, automatically backs up world data
- Requires `HYTALE_BACKUP_DIR` and `HYTALE_BACKUP_FREQUENCY`

**JAVA_OPTS**

- `-Xms`: Initial heap size
- `-Xmx`: Maximum heap size
- Adjust based on available server RAM and player count

## 📂 Data Directory Structure

```
data/
├── Server/                  # Hytale server files
│   └── HytaleServer.jar    # Main server executable
├── Assets.zip              # Game assets
├── config.json             # Server configuration
├── bans.json              # Banned players list
├── whitelist.json         # Whitelisted players
├── permissions.json       # Player permissions
├── logs/                  # Server logs
├── mods/                  # Server mods
├── universe/              # World data
│   ├── players/          # Player data
│   └── worlds/           # World saves
└── backups/              # Automated backups (if enabled)
```

## 🔧 Usage Examples

### Basic Usage

```bash
# Start the server
docker-compose up -d

# View logs
docker-compose logs -f

# Stop the server
docker-compose down

# Restart the server
docker-compose restart
```

### Custom Configuration

Edit `docker-compose.yml` to customize settings:

```yaml
environment:
  JAVA_OPTS: "-Xms2G -Xmx8G" # Increase memory
  HYTALE_BACKUP_FREQUENCY: "60" # Backup every hour
  HYTALE_AUTH_MODE: "offline" # Allow offline mode
```

### Interactive Server Console

Attach to the running container to access the server console:

```bash
docker attach hycker
```

Press `Ctrl+P` then `Ctrl+Q` to detach without stopping the server.

## 🔐 First-Time Setup

On first run, the container will:

1. Download the Hytale downloader tool
2. Prompt for OAuth2 authentication
3. Display a URL and authorization code
4. Open the URL in your browser and authenticate
5. Download and extract server files automatically

**Important**: Keep the `.hytale-downloader-credentials.json` file in your data directory for future updates.

## 🏗️ Building the Image

To build the Docker image locally:

```bash
docker build -t jmbargueno/hycker:latest .
```

To build and push to Docker Hub:

```bash
docker build -t jmbargueno/hycker:1.0.51 .
docker push jmbargueno/hycker:1.0.51
```

## 🩺 Health Checks

The container includes a health check that:

- Runs every 30 seconds
- Checks if the Java process is running
- Allows 60 seconds for initial startup
- Retries 3 times before marking as unhealthy

Check health status:

```bash
docker inspect hycker | grep -A 10 Health
```

## 🛠️ Troubleshooting

### Server won't start

- Check logs: `docker-compose logs`
- Verify `Server/HytaleServer.jar` exists in `./data/Server/`
- Ensure `Assets.zip` is present in `./data/`

### Authentication issues

- Delete `.hytale-downloader-credentials.json` from `./data/`
- Restart container to re-authenticate

### Performance issues

- Increase `JAVA_OPTS` memory allocation
- Reduce `MaxPlayers` in `data/config.json`
- Check server resources with `docker stats hycker`

### Port binding errors

- Ensure port 25573 UDP is not in use
- Check firewall settings
- Verify `HYTALE_BIND_ADDRESS` is set to `0.0.0.0:5520`

## 📝 License

This project is a Docker containerization of the Hytale game server. Hytale and related assets are property of Hypixel Studios.

## 🔗 Links

- **GitHub**: https://github.com/JMBargueno/hycker
- **Docker Hub**: https://hub.docker.com/r/jmbargueno/hycker
- **Hytale**: https://hytale.com/

## 🤝 Contributing

Contributions are welcome! Please feel free to submit issues or pull requests.

1. Fork the repository
2. Create a feature branch
3. Commit your changes
4. Push to the branch
5. Open a Pull Request
