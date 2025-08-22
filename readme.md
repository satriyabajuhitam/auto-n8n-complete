# 🚀 N8N Automatic Installation Script

This script automatically installs and configures a production-ready **N8N Workflow Automation** instance on a clean Ubuntu server. It includes a full suite of extended features to get you up and running quickly and securely.

---

  - **🤖 N8N Core** with FFmpeg and yt-dlp integrated.
  - **☁️ Google Drive & 📱 Telegram Backup** for secure, automated data protection.
  - **🔒 Automatic SSL Certificate** provisioned by Caddy.
  - **💾 Smart Restore System** integrated into the installation process.
  - **🔄 Auto-Update** functionality to keep your instance current.

---

## ✨ Key Features

### 🔧 N8N Core Features

  - **🤖 N8N** with all its powerful automation capabilities.
  - **🎬 FFmpeg** - For professional video and audio processing directly in your workflows.
  - **📺 yt-dlp** - To download videos from YouTube and other sites.
  - **🔒 Automatic SSL** with Caddy reverse proxy for secure HTTPS connections.
  - **📁 Persistent Storage** using Docker volumes to ensure your data is always safe.
  - **⚡ Smart Swap Memory** which is automatically configured based on your server's RAM.

### ☁️ Smart Backup & Restore System

  - **🔄 Automatic Daily Backups** of workflows, credentials, and configuration at 2:00 AM.
  - **📱 Telegram Notifications** to inform you of backup status in real-time.
  - **☁️ Google Drive Uploads** for secure, off-site backup storage.
  - **🗂️ Automatic Cleanup** of old backups locally and on Google Drive.
  - **🔧 Integrated Restore** feature allows you to restore from a backup during a fresh installation.

---

## 🖥️ Supported Environments

✅ **Ubuntu VPS/Server** (22.04 LTS or newer recommended)
✅ **Ubuntu on Windows WSL2**
✅ **Auto-detection** of the operating environment.

---

## 📋 System Requirements

  - **OS**: Ubuntu 20.04 or newer.
  - **RAM**: Minimum 2GB (4GB+ recommended for better performance).
  - **Storage**: 20GB+ of free disk space.
  - **Network**: A domain name pointed to your server's IP address (for Production Mode).
  - **Access**: Root or `sudo` permissions.

---

## 🚀 How to Use

### 1. Download & Run
Download the script, make it executable, and run it with `sudo`.

```bash
# Download the script
wget -O auto_deploy_n8n.sh https://raw.githubusercontent.com/satriyabajuhitam/auto-n8n-complete/main/auto_deploy_n8n.sh

# Or ...
git clone https://github.com/satriyabajuhitam/auto-n8n-complete.git

# Make it executable
chmod +x auto_install_n8n.sh

# Run the installer
sudo ./auto_install_n8n.sh
````

### 2\. Advanced Options

```bash
# Perform a clean install (deletes any previous installation)
sudo ./auto_install_n8n.sh --clean

# Install in Local Mode (no domain required)
sudo ./auto_install_n8n.sh --local

# Specify a custom installation directory
sudo ./auto_install_n8n.sh -d /opt/n8n

# Skip Docker installation (if you already have it)
sudo ./auto_install_n8n.sh --skip-docker

# See all available options
./auto_install_n8n.sh --help
```

---

## 🔧 Interactive Installation Process

The script provides a guided, step-by-step setup:

1.  **🔄 Data Restore Option** - Choose to restore from a backup at the start.
2.  **🏠 Installation Mode** - Select between Production (domain) or Local (IP) mode.
3.  **🌐 Domain Input** - Provide your main domain for N8N (in Production Mode).
4.  **🗑️ Cleanup Option** - Decide whether to remove any old installations.
5.  **💾 Backup Configuration** - Interactively set up Telegram and Google Drive backups.
6.  **🔄 Auto-Update** - Enable or disable automatic updates.
7.  **✅ DNS Verification** - The script confirms your domain is pointed correctly.
8.  **🐳 Docker Installation** - Installs Docker and all required dependencies.
9.  **🏗️ Build & Deploy** - Builds the custom Docker images and starts the services.
10. **🔒 SSL Setup** - Automatically issues a free SSL certificate via Caddy.

---

## 💾 Backup & Restore System

### 🔄 Automatic & Manual Backup

  - **Automatic:** The script configures a cron job to run a full backup every day at **2:00 AM**.
  - **Manual:** You can trigger a backup anytime for testing or maintenance.

<!-- end list -->

```bash
# Run a manual backup with detailed logging
/home/n8n/backup-workflows.sh

# Run a quick manual test with system info
/home/n8n/backup-manual.sh

# View backup logs
tail -f /home/n8n/logs/backup.log
```

### 📦 Backup File Content

Each compressed `.tar.gz` backup file contains the essential data to fully restore your instance:

```
credentials/
├── database.sqlite          # N8N database (workflows, credentials, etc.)
└── encryptionKey            # The encryption key for your credentials
config/
├── docker-compose.yml       # Docker configuration
├── Caddyfile                # Caddy web server configuration
└── telegram_config.txt      # Your Telegram notification settings
└── gdrive_config.txt        # Your Google Drive remote settings
backup_metadata.json         # Information about the backup
```

### 🔧 Restore From a Backup

The easiest way to restore your data is by using the script's integrated restore feature during a fresh installation.

1.  Run the installation script:
    ```bash
    sudo ./auto_install_n8n.sh
    ```
2.  When asked **"Would you like to restore n8n data from an existing backup?"**, answer `y`.
3.  Follow the on-screen prompts to select your backup source (a local file or Google Drive).

The script will automatically handle the extraction and restoration of your data.

---

## 🛠️ System Management

### 🔧 Basic Commands

```bash
# Go to the installation directory
cd /home/n8n

# View container status
docker compose ps

# View real-time logs for all services
docker compose logs -f

# View logs for a specific service (e.g., n8n)
docker compose logs -f n8n

# Restart a specific service
docker compose restart n8n

# Stop all services
docker compose down

# Rebuild and start all services
docker compose up -d --build
```

### 🔍 Troubleshooting & Diagnostics

The script includes a powerful diagnostic tool to help you quickly identify issues.

```bash
# Run the automatic diagnostic script
/home/n8n/troubleshoot.sh
```

This tool checks your system info, container status, Docker networks, SSL certificate, file permissions, and recent error logs.

---

## 📂 Full Directory Structure

```
/home/n8n/
├── 🐳 docker-compose.yml          # Main config with all services
├── 🏗️ Dockerfile                  # N8N custom image configuration
├── 🌐 Caddyfile                   # Reverse proxy + SSL configuration
├── 💾 backup-workflows.sh         # Auto backup script
├── 🧪 backup-manual.sh            # Manual backup test script
├── 🔄 update-n8n.sh               # Auto update script
├── 🏥 health-monitor.sh           # Health check script
├── 🔍 troubleshoot.sh             # Diagnostic script
├── 📱 telegram_config.txt         # Telegram settings (if configured)
├── ☁️ gdrive_config.txt            # Google Drive settings (if configured)
├── 📁 files/                      # N8N persistent data directory
│   ├── database.sqlite            # N8N main database
│   ├── encryptionKey              # N8N encryption key
│   ├── backup_full/               # Local backup storage location
│   ├── temp/                      # Temporary files
│   └── youtube_content_anylystic/ # (Example) Video download location
└── 📋 logs/                       # Log files for script operations
    ├── update.log
    ├── backup.log
    ├── health.log
    └── cron.log
```

---

## 🤝 Support

For bug reports or issues, please provide:

  - **🖥️ OS version** (e.g., Ubuntu 22.04)
  - **🐳 Docker version**
  - **📋 Error logs** from `docker compose logs`
  - **🔧 Steps to reproduce** the issue

---

## 📄 License & Credits

**📜 License**: MIT License

**🙏 Credits**:

  - **N8N Team** - For the amazing workflow automation platform.
  - **Docker** & **Caddy** - For the containerization and web server technologies.

<!-- end list -->
