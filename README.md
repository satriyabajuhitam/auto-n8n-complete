# 🚀 Automated N8N Installation Script

This script automatically installs **N8N Workflow Automation** with a full suite of extended features for 2025, including:

  - **🤖 N8N Core** with FFmpeg and yt-dlp integrated.
  - **📰 News Content API** (FastAPI + Newspaper4k) for advanced content scraping.
  - **☁️ Google Drive & 📱 Telegram Backup** for secure, automated data protection.
  - **🔒 Automatic SSL Certificate** provisioned by Caddy.
  - **💾 Smart Restore System** integrated into the script.
  - **🔄 Auto-Update** functionality to keep your instance current.

## ✨ Outstanding Features 2025

### 🔧 N8N Core Features

  - **🤖 N8N** with all its powerful automation capabilities.
  - **🎬 FFmpeg** - For professional video and audio processing directly in your workflows.
  - **📺 yt-dlp** - To download videos from YouTube, TikTok, Facebook, and more.
  - **🔒 Automatic SSL** with Caddy reverse proxy for secure connections.
  - **📁 Persistent Storage** using Docker volumes to ensure your data is safe.
  - **⚡ Smart Swap Memory** which is automatically configured based on your server's RAM.

### 📰 News Content API (HOT Feature 2025\!)

> **NEW FEATURE 2025\!** 🎉

  - **🚀 Built with FastAPI** and the latest **Newspaper4k** library.
  - **🔐 Secured with Bearer Token Authentication**, configured via a `.env` file.
  - **🌐 Dedicated Subdomain** for easy access: `api.yourdomain.com`.
  - **📱 Responsive UI** with a modern 2025 design.
  - **📚 Interactive API Documentation** via Swagger and ReDoc.
  - **🌍 Multi-language support** including Vietnamese, English, Chinese, Japanese, and more.

**API Endpoints:**

  - `GET /health` - Check API status.
  - `POST /extract-article` - Get full article content from a URL.
  - `POST /extract-source` - Crawl multiple articles from a source website.
  - `POST /parse-feed` - Analyze and parse RSS feeds.

### ☁️ Smart Backup & Restore System

  - **🔄 Automatic Daily Backups** of workflows, credentials, and configuration at 2:00 AM.
  - **📱 Telegram Notifications** to inform you of backup status in real-time.
  - **☁️ Google Drive Uploads** for secure, off-site backup storage.
  - **🗂️ Automatic Cleanup** of old backups locally and on Google Drive.
  - **🔧 Integrated Restore** feature allows you to restore from a backup during installation.

## 🖥️ Supported Environments

✅ **Ubuntu VPS/Server** (Recommended)
✅ **Ubuntu on Windows WSL2**
✅ **Ubuntu Docker Environment**
✅ **Auto-detection** of the operating environment.

## 📋 System Requirements

  - **OS**: Ubuntu 20.04 or newer.
  - **RAM**: Minimum 2GB (4GB+ recommended for better performance).
  - **Storage**: 20GB+ of free disk space.
  - **Network**: A domain name pointed to your server's IP address.
  - **Access**: Root or sudo permissions.

## 🚀 Super Fast Installation

### 1️⃣ One-Command Installation (Recommended)

```bash
cd /tmp && curl -sSL https://raw.githubusercontent.com/satriyabajuhitam/auto-n8n-complete/main/auto_deploy_n8n.sh | tr -d '\r' > deploy_n8n.sh && chmod +x deploy_n8n.sh && sudo bash deploy_n8n.sh
```

### 2️⃣ Or Download & Run

```bash
wget https://raw.githubusercontent.com/satriyabajuhitam/auto-n8n-complete/main/auto_deploy_n8n.sh
chmod +x auto_deploy_n8n.sh
sudo ./auto_deploy_n8n.sh
```

### 3️⃣ Advanced Options

```bash
# Clean install (deletes any previous installation)
sudo ./auto_deploy_n8n.sh --clean

# Specify a custom installation directory
sudo ./auto_deploy_n8n.sh -d /custom/path

# Skip Docker installation (if you already have it)
sudo ./auto_deploy_n8n.sh -s

# See all available options
./auto_deploy_n8n.sh --help
```

## 🔧 Interactive Installation Process

The script provides a guided setup:

1.  **🔄 Data Restore Option** - Choose to restore from a backup at the start.
2.  **🌐 Domain Input** - Provide your main domain for N8N.
3.  **🗑️ Cleanup Option** - Decide whether to remove any old installations.
4.  **📰 News API Setup** - Enable or disable the News Content API.
5.  **🔐 Bearer Token** - Set a secure password for the API.
6.  **☁️ Backup Configuration** - Set up Telegram and Google Drive backups.
7.  **🔄 Auto-Update** - Enable or disable automatic updates.
8.  **✅ DNS Verification** - The script confirms your domain is pointed correctly.
9.  **🐳 Docker Installation** - Installs Docker and all required dependencies.
10. **🏗️ Build & Deploy** - Builds the custom Docker images and starts the services.
11. **🔒 SSL Setup** - Automatically issues a free SSL certificate.

## 📰 News Content API - Usage Guide

### 🔑 Authentication

All API calls require a **Bearer Token** in the authorization header. This token is stored securely in the `.env` file in your installation directory.

```
Authorization: Bearer YOUR_TOKEN_FROM_.ENV_FILE
```

### 📖 API Documentation

After installation, you can access the interactive documentation:

  - **🏠 Homepage**: `https://api.yourdomain.com/`
  - **📚 Swagger UI**: `https://api.yourdomain.com/docs`
  - **📖 ReDoc**: `https://api.yourdomain.com/redoc`

### 💻 Example Usage with cURL

```bash
# Get article content
curl -X POST "https://api.yourdomain.com/extract-article" \
     -H "Content-Type: application/json" \
     -H "Authorization: Bearer YOUR_TOKEN" \
     -d '{
       "url": "https://dantri.com.vn/the-gioi.htm",
       "language": "vi"
     }'
```

### 🔧 Change Bearer Token

To change the API token, edit the `.env` file and restart the service.

1.  **Edit the `.env` file:**

    ```bash
    nano /home/n8n/.env
    ```

2.  Find the line `NEWS_API_TOKEN="..."` and replace the value. Save the file.

3.  **Restart the API service:**

    ```bash
    cd /home/n8n && docker compose restart fastapi
    ```

## 💾 Backup & Restore System

### 🔄 Automatic & Manual Backup

  - **Automatic:** The script configures a cron job to run a full backup every day at **2:00 AM**.
  - **Manual:** You can trigger a backup anytime for testing or maintenance.

<!-- end list -->

```bash
# Run a manual backup
/home/n8n/backup-workflows.sh

# Run a manual test with system info
/home/n8n/backup-manual.sh

# View backup logs
tail -f /home/n8n/logs/backup.log
```

### 📦 Backup File Content

Each compressed `.tar.gz` backup file contains the essential data to fully restore your instance:

```
credentials/
├── database.sqlite          # N8N database (contains all workflows, credentials, etc.)
└── encryptionKey            # The encryption key for your credentials
config/
├── .env                     # Environment file with secrets (IMPORTANT!)
├── docker-compose.yml       # Docker configuration
└── Caddyfile                # Caddy web server configuration
backup_metadata.json          # Information about the backup
```

### 🔧 Restore From a Backup

The easiest way to restore your data is by using the script's integrated restore feature during a fresh installation.

1.  Run the installation script:
    ```bash
    sudo ./auto_deploy_n8n.sh
    ```
2.  When asked **"Do you want to restore data from an existing backup?"**, answer `y`.
3.  Follow the on-screen prompts to select your backup source (a local file or Google Drive).

The script will automatically handle the extraction and restoration of your database, encryption key, and critical configurations.

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

This tool checks your system info, container status, network ports, SSL certificates, file permissions, and recent error logs.

## 📂 Full Directory Structure

```
/home/n8n/
├── 🔐 .env                       # Secure environment variables (tokens, keys)
├── 🐳 docker-compose.yml          # Main config with all services
├── 🏗️ Dockerfile                  # N8N custom image configuration
├── 🌐 Caddyfile                   # Reverse proxy + SSL configuration
├── 💾 backup-workflows.sh         # Auto backup script
├── 🧪 backup-manual.sh            # Manual backup test script
├── 🔄 update-n8n.sh               # Auto update script
├── 🔍 troubleshoot.sh             # Diagnostic script
├── 📱 telegram_config.txt         # Telegram settings (if configured)
├── ☁️ gdrive_config.txt            # Google Drive settings (if configured)
├── 📁 files/                      # N8N persistent data directory
│   ├── database.sqlite            # N8N main database
│   ├── encryptionKey              # N8N encryption key
│   ├── backup_full/               # Backup storage location
│   ├── temp/                      # Temporary files
│   └── youtube_content_anylystic/ # Video download location
├── 📰 news_api/                   # News API source code (if installed)
│   ├── Dockerfile
│   ├── requirements.txt
│   └── main.py
└── 📋 logs/                       # Log files for script operations
    ├── update.log
    ├── backup.log
    ├── health.log
    └── cron.log
```

## 🤝 Contributing & Support

### 💬 Get Support

  - **🐛 Issues**: [GitHub Issues](https://github.com/satriyabajuhitam/auto-n8n-complete/issues)
  - **🎥 YouTube**: [Satriya Baju Hitam](https://www.youtube.com/@satriyabajuhitam) - **SUBSCRIBE TO SUPPORT\!**
  - **📱 Whatsapp**: 628123456789

### 📝 Bug Reports

When reporting a bug, please include:

  - **🖥️ OS version** (e.g., Ubuntu 22.04)
  - **🐳 Docker version**
  - **📋 Error logs** from `docker compose logs`
  - **🔧 Steps to reproduce** the issue

## 📄 License & Credits

**📜 License**: MIT License

**🙏 Credits**:

  - **N8N Team** - For the amazing workflow automation platform.
  - **Newspaper4k** - For the powerful Python article extraction library.
  - **FastAPI** - For the modern Python web framework.
  - **Docker** & **Caddy** - For the containerization and web server platforms.
