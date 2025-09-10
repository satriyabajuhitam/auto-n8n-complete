# 🚀 Automated N8N Installation Script

Automated installation script for **N8N Workflow Automation**, including:

  - **🤖 N8N** with FFmpeg, yt-dlp, Puppeteer
  - **📱 Daily automated Telegram Backup**
  - **🔒 Automatic SSL Certificate** with Caddy
  - **💾 Smart Backup System** with compression
  - **🔄 Auto-Update** with options

---

## ✨ Highlighted Features

### 🔧 N8N Core Features

  - **🤖 N8N** with all automation features
  - **🎬 FFmpeg** - Professional video/audio processing
  - **📺 yt-dlp** - Download YouTube/TikTok/Facebook videos
  - **🌐 Puppeteer + Chromium** - Browser automation
  - **🔒 Automatic SSL** with Caddy reverse proxy
  - **📁 Volume mapping** for file persistence
  - **⚡ Swap memory** automatically based on RAM

### 📱 Telegram Backup System

  - **🔄 Automatic backup** of workflows & credentials every day at 2:00 AM
  - **📱 Sends backup file** via Telegram Bot (if <20MB)
  - **📊 Real-time notifications** on backup status
  - **🗂️ Automatically keeps the last 30 backups**
  - **🧪 Test manual backup** for verification

---

### 💾 Smart Backup System

  - **📋 Export workflows** from N8N database
  - **🔐 Backup credentials** & encryption keys
  - **📦 Compression** with tar.gz
  - **📊 Metadata tracking** (version, size, date)
  - **🧹 Auto cleanup** of old backups
  - **📋 Detailed logging** of all activities

---

## 🖥️ Supported Environments

  - ✅ **Ubuntu VPS/Server** (Recommended)
  - ✅ **Ubuntu on Windows WSL2**
  - ✅ **Ubuntu Docker Environment**
  - ✅ **Auto-detect** and handle the environment

---

## 📋 System Requirements

  - **OS**: Ubuntu 20.04+ (VPS or WSL)
  - **RAM**: Minimum 2GB (4GB+ recommended)
  - **Storage**: 20GB+ free space
  - **Network**: Domain pointed to the server IP
  - **Access**: Root/sudo permissions

---

## 🚀 Super Fast Installation

### 1️⃣ One-Command Install (Recommended)

```bash
cd /tmp && curl -sSL https://raw.githubusercontent.com/satriyabajuhitam/auto-n8n-complete/main/auto_deploy_n8n.sh | tr -d '\r' > install_n8n.sh && chmod +x install_n8n.sh && sudo bash install_n8n.sh
````

### 2️⃣ Or Download & Run

```bash
wget https://raw.githubusercontent.com/satriyabajuhitam/auto-n8n-complete/main/auto_deploy_n8n.sh
chmod +x auto_deploy_n8n.sh
sudo ./auto_deploy_n8n.sh
```

### 3️⃣ Clean Install (Deletes all old installations)

```bash
sudo ./auto_deploy_n8n.sh --clean
```

### 4️⃣ Advanced Options

```bash
# Specify installation directory
sudo ./auto_deploy_n8n.sh -d /custom/path

# Skip Docker installation (if already installed)
sudo ./auto_deploy_n8n.sh -s

# View full help
./auto_deploy_n8n.sh -h
```

-----

## 🔧 Interactive Installation Process

The script will guide you through each step:

1.  **🔄 Setup Swap** - Automatically calculates and sets up appropriate swap space
2.  **🌐 Enter Domain** - Main domain for N8N
3.  **🗑️ Cleanup Option** - Option to delete old installations (if any)
4.  **📱 Telegram Config** - Do you want to back up via Telegram?
5.  **🔄 Auto-Update** - Do you want to enable automatic updates?
6.  **✅ DNS Verification** - Checks if the domain is pointed correctly
7.  **🐳 Docker Installation** - Installs Docker & dependencies
8.  **🏗️ Build & Deploy** - Builds images and starts containers
9.  **🔒 SSL Setup** - Automatically issues an SSL certificate

-----

## 📱 Telegram Backup System

### 🔧 Configure Telegram Bot

**1. 🤖 Create a Bot:**

  - Open Telegram, search for **@BotFather**
  - Send the command: `/newbot`
  - Set a name and username for the bot
  - **Copy the Bot Token** you receive

**2. 🆔 Get Chat ID:**

**For an individual:**

  - Search for **@userinfobot** on Telegram
  - Send `/start` to get your **User ID**

**For a group:**

  - Add the bot to the group
  - Send a message in the group
  - Visit: `https://api.telegram.org/bot<BOT_TOKEN>/getUpdates`
  - The **group Chat ID** will start with a minus sign (-)

### 📱 Test Telegram Integration

```bash
# Test sending a message
curl -X POST "https://api.telegram.org/bot<BOT_TOKEN>/sendMessage" \
     -d chat_id="<CHAT_ID>" \
     -d text="Test message from N8N backup system!"
```

### 🔄 Backup Features

  - **⏰ Automatic**: Every day at 2:00 AM
  - **📱 Notifications**: Real-time via Telegram
  - **📦 File Transfer**: Auto-sends the backup file (if \<20MB)
  - **📊 Statistics**: Number of workflows, size, time
  - **🗂️ Retention**: Keeps the last 30 backups

-----

## 💾 Backup & Restore System

### 🔄 Automatic Backup

The script automatically backs up every day at **2:00 AM**:

  - **📋 Workflows** and **Credentials** from N8N
  - **💾 Database** (SQLite) with all data
  - **🔐 Encryption keys** and config files
  - **📦 Compression** with gzip to save space

### 🧪 Manual Backup Test

```bash
# Run a backup test to verify
/home/n8n/backup-manual.sh

# Run a regular backup
/home/n8n/backup-workflows.sh

# View backup logs
tail -f /home/n8n/files/backup_full/backup.log
```

### 📁 Backup Structure

```
/home/n8n/files/backup_full/
├── n8n_backup_20241227_140000.tar.gz   # Today's backup
├── n8n_backup_20241226_140000.tar.gz   # Yesterday's backup
├── n8n_backup_20241225_140000.tar.gz   # Backup from 2 days ago
├── ...                                 # Up to 30 files
└── backup.log                          # Log file
```

### 📦 Backup File Contents

Each backup file contains:

```
backup_metadata.json          # Backup information
workflows/                    # All exported workflows
├── 1-My_Workflow.json
├── 2-Another_Workflow.json
└── workflows.json           # List of workflows
credentials/                 # Credentials & database
├── database.sqlite          # N8N database
└── encryptionKey           # Encryption key
config/                     # Config files (if any)
```

### 🔧 Restore from Backup

```bash
# 1. Stop containers
cd /home/n8n && docker-compose down

# 2. Extract the backup
cd /home/n8n/files/backup_full
tar -xzf n8n_backup_YYYYMMDD_HHMMSS.tar.gz

# 3. Copy files to their original locations
cp credentials/database.sqlite /home/n8n/
cp credentials/encryptionKey /home/n8n/
# Workflows will be automatically imported when N8N starts

# 4. Restart
cd /home/n8n && docker-compose up -d
```

-----

## 🛠️ System Management

### 🔧 Basic Commands

```bash
# View container status
cd /home/n8n && docker-compose ps

# View real-time logs
cd /home/n8n && docker-compose logs -f

# Restart individual services
cd /home/n8n && docker-compose restart n8n
cd /home/n8n && docker-compose restart caddy

# Rebuild everything
cd /home/n8n && docker-compose down && docker-compose up -d --build
```

### 🔍 Troubleshooting & Diagnostics

```bash
# Automated diagnostic script (NEW FEATURE!)
/home/n8n/troubleshoot.sh

# Check Docker status
docker ps --filter "name=n8n"

# View detailed logs
cd /home/n8n && docker-compose logs n8n
cd /home/n8n && docker-compose logs caddy

# Check disk usage
df -h
docker system df

# Check memory
free -h
docker stats --no-stream
```

### 🔄 Updates & Maintenance

```bash
# Automatic update (every 12h if enabled)
/home/n8n/update-n8n.sh

# Manual component update
docker exec -it n8n_container pip3 install --break-system-packages -U yt-dlp

# Clean Docker cache
docker system prune -f
docker image prune -f
```

-----

## 📂 Complete Directory Structure

```
/home/n8n/
├── 🐳 docker-compose.yml          # Main config with all services
├── 🏗️ Dockerfile                  # N8N custom image
├── 🌐 Caddyfile                   # Reverse proxy + SSL config
├── 💾 backup-workflows.sh         # Auto backup script
├── 🧪 backup-manual.sh            # Manual backup test script
├── 🔄 update-n8n.sh               # Auto update script
├── 🔍 troubleshoot.sh             # Diagnostic script (NEW!)
├── 📱 telegram_config.txt         # Telegram settings (if any)
├── 📁 files/                      # N8N data directory
│   ├── backup_full/                # 💾 Backup storage (30 files)
│   ├── temp/                       # 🗂️ Temporary files
│   └── youtube_content_anylystic/  # 🎬 Video downloads
├── 💾 database.sqlite             # N8N main database
├── 🔐 encryptionKey               # N8N encryption key
└── 📋 logs/                       # Log files
    ├── update.log                 # Update logs
    └── backup.log                 # Backup logs
```

-----

## ⚡ Performance & Optimization

### 🚀 System Optimization

1.  **💾 Memory**: Script automatically sets up swap based on RAM
2.  **⚡ CPU**: Single worker for stability
3.  **🗂️ Disk**: Auto cleanup of old backups & Docker cache
4.  **🌐 Network**: Caddy gzip compression enabled
5.  **🔧 Docker**: Optimized images with multi-stage builds

### 📊 Performance Monitoring

```bash
# Real-time resource usage
docker stats

# Disk usage breakdown
df -h
du -sh /home/n8n/*

# Memory usage detail
free -h && swapon --show

# Network connections
netstat -tulpn | grep :80
netstat -tulpn | grep :443
```

### 🎛️ Performance Tuning

```bash
# Increase Docker memory limits (if needed)
nano /home/n8n/docker-compose.yml
# Add: mem_limit: 2g

# Optimize N8N settings
# In the N8N container environment:
# N8N_EXECUTIONS_DATA_MAX_SIZE=500MB
# N8N_EXECUTIONS_TIMEOUT=3600
```

-----

## 🐛 Troubleshooting Guide

### ❌ Common Errors & Fixes

**1. 🐳 Docker daemon not running (WSL)**

```bash
# Start the Docker daemon
sudo dockerd &

# Or restart the Docker service
sudo systemctl restart docker

# Check status
sudo systemctl status docker
```

**2. 🌐 Domain not pointed correctly**

```bash
# Check DNS propagation
dig yourdomain.com A
nslookup yourdomain.com 8.8.8.8

# Check server IP
curl -s https://api.ipify.org

# Wait for DNS propagation (5-60 minutes)
```

**3. 🐳 Container won't start**

```bash
# View detailed logs
cd /home/n8n && docker-compose logs

# Cleanup and rebuild
docker system prune -f
cd /home/n8n && docker-compose down
docker-compose up -d --build

# If still failing, check ports
sudo netstat -tulpn | grep :80
sudo netstat -tulpn | grep :443
```

**4. 🔒 SSL Certificate issues**

```bash
# View Caddy logs
cd /home/n8n && docker-compose logs caddy

# Force SSL renewal
docker-compose restart caddy

# Check domain accessibility
curl -I https://yourdomain.com
```

**5. 📱 Telegram backup not working**

```bash
# Test Telegram Bot
curl -X POST "https://api.telegram.org/bot<BOT_TOKEN>/getMe"

# Test sending a message
curl -X POST "https://api.telegram.org/bot<BOT_TOKEN>/sendMessage" \
     -d chat_id="<CHAT_ID>" \
     -d text="Test message"

# Check config file
cat /home/n8n/telegram_config.txt
```

**6. 💾 Backup failed**

```bash
# Run manual backup to debug
/home/n8n/backup-manual.sh

# View detailed log
tail -f /home/n8n/files/backup_full/backup.log

# Check permissions
ls -la /home/n8n/files/backup_full/
```

### 🔧 Recovery Commands

```bash
# 🧹 Clean reinstall (DELETES EVERYTHING!)
sudo rm -rf /home/n8n
sudo ./auto_cai_dat_n8n.sh --clean

# 🔄 Soft restart services
cd /home/n8n
docker-compose restart

# 💾 Restore from backup
cd /home/n8n/files/backup_full
tar -xzf n8n_backup_YYYYMMDD_HHMMSS.tar.gz
# Copy files to their original locations

# 🐳 Reset Docker completely
sudo systemctl stop docker
sudo systemctl start docker
cd /home/n8n && docker-compose up -d
```

### 🩺 Health Check Commands

```bash
# Comprehensive system check
/home/n8n/troubleshoot.sh

# Quick status check
cd /home/n8n && docker-compose ps

# Service-specific checks
curl -I https://yourdomain.com                   # N8N
systemctl status docker                          # Docker
systemctl status cron                            # Cron jobs
```

-----

## 🌟 Features Roadmap 2025

  - [ ] **🌍 Multi-domain** support for multiple N8N instances
  - [ ] **📊 Monitoring dashboard** with Grafana
  - [ ] **☸️ Kubernetes** deployment option
  - [ ] **🔗 External database** support (PostgreSQL)
  - [ ] **📈 Auto-scaling** based on load
  - [ ] **🛒 Plugin marketplace** integration
  - [ ] **🔔 Advanced notifications** (Discord, Slack, Email)
  - [ ] **🧠 AI content** analysis integration

### 🔧 Contributing

1.  **🍴 Fork** this repository
2.  **🌿 Create feature branch**: `git checkout -b feature/amazing-feature`
3.  **💾 Commit changes**: `git commit -m 'Add amazing feature'`
4.  **📤 Push to branch**: `git push origin feature/amazing-feature`
5.  **🔄 Create Pull Request**

### 📝 Bug Reports

When reporting a bug, please include:

  - **🖥️ OS version** (Ubuntu 20.04, 22.04, etc.)
  - **🐳 Docker version**
  - **📋 Error logs** from `docker-compose logs`
  - **🔧 Steps to reproduce**

**🙏 Credits**:

  - **N8N Team** - Workflow automation platform
  - **🐳 Docker** - Containerization platform
  - **🌐 Caddy** - Web server with automatic HTTPS
