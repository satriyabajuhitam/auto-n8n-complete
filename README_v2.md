# 🚀 Automated N8N Installation Script

This script automatically installs **N8N Workflow Automation** with a full suite of extended features for 2025, including:

- **🤖 N8N Core** with FFmpeg and yt-dlp integrated.
- **🐘 Production-Ready Database** with a choice between PostgreSQL (recommended) and SQLite.
- **☁️ Google Drive & 📱 Telegram Backup** for secure, automated data protection.
- **🔒 Automatic SSL Certificate** provisioned by Caddy.
- **💾 Smart Restore System** integrated into the script.
- **🔄 Auto-Update** functionality to keep your instance current.

## ✨ Outstanding Features 2025

### 🔧 N8N Core Features

- **🤖 N8N** with all its powerful automation capabilities.
- **🐘 Flexible Database**: Choose between simple **SQLite** for basic needs or robust **PostgreSQL** for production-grade performance and scalability.
- **🎬 FFmpeg** - For professional video and audio processing directly in your workflows.
- **📺 yt-dlp** - To download videos from YouTube, TikTok, Facebook, and more.
- **🔒 Automatic SSL** with Caddy reverse proxy for secure connections.
- **📁 Persistent Storage** using Docker volumes to ensure your data is safe.
- **⚡ Smart Swap Memory** which is automatically configured based on your server's RAM.

### ☁️ Smart Backup & Restore System

- **🔄 Automatic Daily Backups** of your chosen database (PostgreSQL or SQLite), workflows, credentials, and configuration at 2:00 AM.
- **📱 Telegram Notifications** to inform you of backup status in real-time.
- **☁️ Google Drive Uploads** for secure, off-site backup storage.
- **🗂️ Automatic Cleanup** of old backups locally and on Google Drive.
- **🔧 Integrated Restore** feature allows you to restore from a backup during installation.

## 🐘 Which Database Should You Choose: PostgreSQL vs. SQLite

This script gives you a choice between two powerful databases. Here’s a simple guide to help you decide.

**In short: If you're unsure, choose PostgreSQL.** The script automates the setup for you.

| Criteria | SQLite (Personal Notebook) 📝 | PostgreSQL (Public Library) 🐘 |
| :--- | :--- | :--- |
| **Best Use Case** | Personal use, hobbies, testing, or servers with very limited resources (e.g., 1GB RAM). | **Production, business, teams,** or if you plan to run many workflows concurrently. |
| **Performance** | Very fast for single operations, but can slow down when many workflows run at the same time. | **Superior** for handling many concurrent workflows and complex queries (e.g., viewing execution history). |
| **Scalability** | Limited. Not ideal if your number of workflows and execution data grows very large. | **Excellent**. Designed to handle large databases and high workloads. The right choice for the long term. |
| **Resource Usage**| **Very light**. Adds almost no extra RAM/CPU usage. | **Higher**. Runs a separate container that will use some of your server's RAM & CPU (but it's worth the performance). |
| **Data Reliability** | Quite reliable, but more susceptible to file corruption in case of a server crash. | **Very reliable**. Has advanced mechanisms to ensure data integrity, even during system failures. |

**Recommendation:** For a server with **2 CPUs and 4GB of RAM**, **PostgreSQL is a much stronger foundation**. It will provide a faster and more stable experience as your number of workflows grows.

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
cd /tmp && curl -sSL https://raw.githubusercontent.com/satriyabajuhitam/auto-n8n-complete/main/auto_deploy_n8n_v2.sh | tr -d '\r' > deploy_n8n_v2.sh && chmod +x deploy_n8n_v2.sh && sudo bash deploy_n8n_v2.sh
````

### 2️⃣ Or Download & Run

```bash
wget https://raw.githubusercontent.com/satriyabajuhitam/auto-n8n-complete/main/auto_deploy_n8n_v2.sh
chmod +x auto_deploy_n8n_v2.sh
sudo ./auto_deploy_n8n_v2.sh
```

## 🔧 Interactive Installation Process

The script provides a guided setup:

1.  **🔄 Data Restore Option** - Choose to restore from a backup at the start.
2.  **🌐 Domain Input** - Provide your main domain for N8N.
3.  **🐘 Database Selection** - Choose between PostgreSQL (recommended) or SQLite.
4.  **🗑️ Cleanup Option** - Decide whether to remove any old installations.
5.  **☁️ Backup Configuration** - Set up Telegram and Google Drive backups.
6.  **🔄 Auto-Update** - Enable or disable automatic updates.
7.  **✅ DNS Verification** - The script confirms your domain is pointed correctly.
8.  **🐳 Docker Installation** - Installs Docker and all required dependencies.
9.  **🏗️ Build & Deploy** - Builds the custom Docker images and starts the services.
10. **🔒 SSL Setup** - Automatically issues a free SSL certificate.

## 💾 Backup & Restore System

### 🔄 Automatic & Manual Backup

  - **Automatic:** The script configures a cron job to run a full backup every day at **2:00 AM**.
  - **Manual:** You can trigger a backup anytime for testing or maintenance.

<!-- end list -->

```bash
# Run a manual backup
/home/n8n/backup-workflows.sh
```

### 📦 Backup File Content

The content of the backup file depends on the database you chose during installation:

**If using SQLite:** a `database.sqlite` file is included.
**If using PostgreSQL:** a `database.sql` dump file is included.

### 🔧 Restore From a Backup

The easiest way to restore your data is by using the script's integrated restore feature during a fresh installation. The script will automatically detect whether the backup is for SQLite or PostgreSQL and handle the restoration process accordingly.

## 🛠️ System Management

### 🔧 Basic Commands

```bash
# Go to the installation directory
cd /home/n8n

# View container status
docker compose ps

# View real-time logs for all services
docker compose logs -f

# View logs for a specific service (e.g., n8n or postgres)
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

## 📂 Full Directory Structure

```
/home/n8n/
├── 🔐 .env                       # Secure environment variables (tokens, keys, DB passwords)
├── 🐳 docker-compose.yml          # Main config with all services
├── 🏗️ Dockerfile                  # N8N custom image configuration
├── 🌐 Caddyfile                   # Reverse proxy + SSL configuration
├── 💾 backup-workflows.sh         # Auto backup script (DB-aware)
├── 🧪 backup-manual.sh            # Manual backup test script
├── 🔄 update-n8n.sh               # Auto update script
├── 🔍 troubleshoot.sh             # Diagnostic script
├── 📱 telegram_config.txt         # Telegram settings (if configured)
├── ☁️ gdrive_config.txt            # Google Drive settings (if configured)
├── 📁 files/                      # N8N persistent data directory (for SQLite)
├── 🐘 postgres_data/             # PostgreSQL persistent data (if installed)
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
  - **📱 Whatsapp**: +628123456789

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
  - **PostgreSQL Team** - For the powerful open-source object-relational database system.
  - **Docker** & **Caddy** - For the containerization and web server platforms.

<!-- end list -->
