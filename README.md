# 🚀 Automated N8N Installation Script with FFmpeg, yt-dlp, Puppeteer, and News API


This script automatically installs **N8N Workflow Automation** with full extended features for 2025, including:

  - **🤖 N8N** with FFmpeg, yt-dlp, Puppeteer
  - **📰 News Content API** (FastAPI + Newspaper4k)
  - **📱 Daily Automatic Telegram Backup**
  - **🔒 Automatic SSL Certificate** with Caddy
  - **💾 Smart Backup System** with compression
  - **🔄 Auto-Update** with options

## ✨ Outstanding Features 2025

### 🔧 N8N Core Features

  - **🤖 N8N** with all automation features
  - **🎬 FFmpeg** - Professional video/audio processing
  - **📺 yt-dlp** - Download YouTube/TikTok/Facebook videos
  - **🌐 Puppeteer + Chromium** - Browser automation
  - **🔒 Automatic SSL** with Caddy reverse proxy
  - **📁 Volume mapping** for file persistence
  - **⚡ Swap memory** automatically adjusted by RAM

### 📰 News Content API (HOT Feature 2025\!)

> **NEW FEATURE 2025\!** 🎉

  - **🚀 FastAPI** with the latest **Newspaper4k**
  - **🔐 Customizable Bearer Token Authentication** for security
  - **🌐 Dedicated Subdomain**: `api.yourdomain.com`
  - **📱 Responsive UI** with 2025 design
  - **📚 Interactive Documentation** (Swagger + ReDoc)
  - **🌍 Multi-language support** (Vietnamese, English, Chinese, Japanese...)

**API Endpoints:**

  - `GET /health` - Check API status
  - `POST /extract-article` - Get article content from URL
  - `POST /extract-source` - Crawl multiple articles from a website
  - `POST /parse-feed` - Analyze RSS feeds

### 📱 Telegram Backup System (HOT Feature\!)

  - **🔄 Automatic backup** of workflows & credentials every day at 2:00 AM
  - **📱 Sends backup file** via Telegram Bot (if \<20MB)
  - **📊 Real-time notifications** about backup status
  - **🗂️ Automatically keeps the 30 most recent backups**
  - **🧪 Manual backup test** to check functionality

### 💾 Smart Backup System

  - **📋 Export workflows** from N8N database
  - **🔐 Backup credentials** & encryption keys
  - **📦 Compression** with tar.gz
  - **📊 Metadata tracking** (version, size, date)
  - **🧹 Auto cleanup** of old backups
  - **📋 Detailed logging** of all activities

## 🖥️ Supported Environments

✅ **Ubuntu VPS/Server** (Recommended)
✅ **Ubuntu on Windows WSL2**
✅ **Ubuntu Docker Environment**
✅ **Auto-detect** and handle the environment

## 📋 System Requirements

  - **OS**: Ubuntu 20.04+ (VPS or WSL)
  - **RAM**: Minimum 2GB (4GB+ recommended)
  - **Storage**: 20GB+ free space
  - **Network**: Domain already pointed to the server IP
  - **Access**: Root/sudo permissions

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

### 3️⃣ Clean Installation (Deletes all previous installations)

```bash
sudo ./auto_deploy_n8n.sh --clean
```

### 4️⃣ Advanced Options

```bash
# Specify installation directory
sudo ./auto_deploy_n8n.sh -d /custom/path

# Skip Docker installation (if already installed)
sudo ./auto_deploy_n8n.sh -s

# See full help
./auto_deploy_n8n.sh -h
```

## 🔧 Interactive Installation Process

The script will guide you through each step:

1.  **🔄 Setup Swap** - Automatically calculates and sets up suitable swap memory
2.  **🌐 Enter Domain** - Main domain for N8N
3.  **🗑️ Cleanup Option** - Option to delete old installations (if any)
4.  **📰 News API Setup** - Do you want to install the News Content API?
5.  **🔐 Bearer Token** - Set a secure Bearer Token password
6.  **📱 Telegram Config** - Do you want to back up via Telegram?
7.  **🔄 Auto-Update** - Do you want automatic updates?
8.  **✅ DNS Verification** - Checks if the domain is correctly pointed
9.  **🐳 Docker Installation** - Installs Docker & dependencies
10. **🏗️ Build & Deploy** - Builds images and starts containers
11. **🔒 SSL Setup** - Automatically issues SSL certificate

## 📰 News Content API - SUPER HOT FEATURE 2025\!

### 🎯 Introduction

The News Content API is built with **FastAPI** and the latest **Newspaper4k** version, helping you to:

  - **📰 Scrape content** from any website
  - **📡 Parse RSS feeds** to get the latest news
  - **🔍 Search** and analyze content automatically
  - **🤖 Integrate** directly into N8N workflows

### 🔑 Authentication

All API calls require a **custom Bearer Token**:

```bash
Authorization: Bearer YOUR_CUSTOM_TOKEN_HERE
```

> **🔐 Security:** The script will ask you to set your own Bearer Token (at least 20 characters) to ensure maximum security\!

### 📖 API Documentation

After installation, access:

  - **🏠 Homepage**: `https://api.yourdomain.com/`
  - **📚 Swagger UI**: `https://api.yourdomain.com/docs`
  - **📖 ReDoc**: `https://api.yourdomain.com/redoc`

### 💻 Example Usage with cURL

**1. 🩺 Check API:**

```bash
curl -X GET "https://api.yourdomain.com/health" \
     -H "Authorization: Bearer YOUR_CUSTOM_TOKEN"
```

**2. 📰 Get article content:**

```bash
curl -X POST "https://api.yourdomain.com/extract-article" \
     -H "Content-Type: application/json" \
     -H "Authorization: Bearer YOUR_CUSTOM_TOKEN" \
     -d '{
       "url": "https://dantri.com.vn/the-gioi.htm",
       "language": "vi",
       "extract_images": true,
       "summarize": true
     }'
```

**3. 🌐 Crawl multiple articles from a website:**

```bash
curl -X POST "https://api.yourdomain.com/extract-source" \
     -H "Content-Type: application/json" \
     -H "Authorization: Bearer YOUR_CUSTOM_TOKEN" \
     -d '{
       "url": "https://dantri.com.vn",
       "max_articles": 10,
       "language": "vi"
     }'
```

**4. 📡 Parse RSS Feed:**

```bash
curl -X POST "https://api.yourdomain.com/parse-feed" \
     -H "Content-Type: application/json" \
     -H "Authorization: Bearer YOUR_CUSTOM_TOKEN" \
     -d '{
       "url": "https://dantri.com.vn/rss.xml",
       "max_articles": 10
     }'
```

### 🔧 Change Bearer Token {\#change-token}

**Method 1: Via Docker Environment**

```bash
cd /home/n8n
sed -i 's/NEWS_API_TOKEN=.*/NEWS_API_TOKEN=NEW_TOKEN_HERE/' docker-compose.yml
docker-compose restart fastapi
```

**Method 2: Direct Edit**

```bash
nano /home/n8n/docker-compose.yml
# Find the line NEWS_API_TOKEN and change it
docker-compose restart fastapi
```

**Method 3: One-liner command**

```bash
cd /home/n8n && sed -i 's/NEWS_API_TOKEN=.*/NEWS_API_TOKEN="YOUR_NEW_TOKEN"/' docker-compose.yml && docker-compose restart fastapi
```

### 🤖 Usage in N8N Workflows

**1. Create an HTTP Request Node:**

  - **Method**: POST
  - **URL**: `https://api.yourdomain.com/extract-article`
  - **Authentication**: Header Auth
      - **Name**: `Authorization`
      - **Value**: `Bearer YOUR_CUSTOM_TOKEN`

**2. Request Body:**

```json
{
  "url": "{{ $json.article_url }}",
  "language": "vi",
  "extract_images": true,
  "summarize": false
}
```

**3. The Response will contain:**

```json
{
  "title": "Article Title",
  "content": "Full content...",
  "summary": "Article summary",
  "authors": ["Author"],
  "publish_date": "2024-12-27T10:00:00Z",
  "images": ["url1.jpg", "url2.jpg"],
  "word_count": 500,
  "read_time_minutes": 3
}
```

## 📱 Telegram Backup System

### 🔧 Telegram Bot Configuration

**1. 🤖 Create Bot:**

  - Open Telegram, find **@BotFather**
  - Send command: `/newbot`
  - Set a name and username for the bot
  - **Copy the received Bot Token**

**2. 🆔 Get Chat ID:**

**For individuals:**

  - Find **@userinfobot** on Telegram
  - Send `/start` to get your **User ID**

**For groups:**

  - Add the bot to the group
  - Send a message in the group
  - Access: `https://api.telegram.org/bot<BOT_TOKEN>/getUpdates`
  - **The group Chat ID** starts with a minus sign (-)

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
  - **📦 File Transfer**: Automatically sends the backup file (if \<20MB)
  - **📊 Statistics**: Number of workflows, size, time
  - **🗂️ Retention**: Keeps the 30 most recent backups

## 💾 Backup & Restore System

### 🔄 Automatic Backup

The script automatically backs up every day at **2:00 AM**:

  - **📋 Workflows** and **Credentials** from N8N
  - **💾 Database** (SQLite) with all data
  - **🔐 Encryption keys** and config files
  - **📦 Compression** with gzip to save space

### 🧪 Manual Backup Test

```bash
# Run a backup test to check
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
├── n8n_backup_20241225_140000.tar.gz   # 2 days ago backup
├── ...                                 # Max 30 copies
└── backup.log                          # Log file
```

### 📦 Backup File Content

Each backup file contains:

```
backup_metadata.json          # Backup information
workflows/                    # All exported workflows
├── 1-My_Workflow.json
├── 2-Another_Workflow.json
└── workflows.json           # List of workflows
credentials/                 # Credentials & database
├── database.sqlite          # N8N database
└── encryptionKey            # Encryption key
config/                      # Config files (if any)
```

### 🔧 Restore from Backup

```bash
# 1. Stop containers
cd /home/n8n && docker-compose down

# 2. Unzip backup
cd /home/n8n/files/backup_full
tar -xzf n8n_backup_YYYYMMDD_HHMMSS.tar.gz

# 3. Copy files to the old location
cp credentials/database.sqlite /home/n8n/
cp credentials/encryptionKey /home/n8n/
# Workflows will be automatically imported when N8N starts

# 4. Restart
cd /home/n8n && docker-compose up -d
```

## 🛠️ System Management

### 🔧 Basic Commands

```bash
# View container status
cd /home/n8n && docker-compose ps

# View real-time logs
cd /home/n8n && docker-compose logs -f

# Restart a specific service
cd /home/n8n && docker-compose restart n8n
cd /home/n8n && docker-compose restart caddy
cd /home/n8n && docker-compose restart fastapi  # If News API is installed

# Rebuild everything
cd /home/n8n && docker-compose down && docker-compose up -d --build
```

### 🔍 Troubleshooting & Diagnostics

```bash
# Automatic diagnostic script (NEW FEATURE!)
/home/n8n/troubleshoot.sh

# Check Docker status
docker ps --filter "name=n8n"

# View detailed logs
cd /home/n8n && docker-compose logs n8n
cd /home/n8n && docker-compose logs caddy
cd /home/n8n && docker-compose logs fastapi  # News API

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

# Manual update components
docker exec -it n8n_container pip3 install --break-system-packages -U yt-dlp

# Clean Docker cache
docker system prune -f
docker image prune -f
```

## 📂 Full Directory Structure

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
├── 🔑 news_api_token.txt          # News API token (if any)
├── 📁 files/                      # N8N data directory
│   ├── backup_full/               # 💾 Backup storage (30 copies)
│   ├── temp/                      # 🗂️ Temporary files
│   └── youtube_content_anylystic/ # 🎬 Video downloads
├── 📰 news_api/                   # News API (if any)
│   ├── Dockerfile
│   ├── requirements.txt           # Python dependencies
│   ├── main.py                    # FastAPI application
│   └── start_news_api.sh          # Startup script
├── 💾 database.sqlite             # N8N main database
├── 🔐 encryptionKey               # N8N encryption key
└── 📋 logs/                       # Log files
    ├── update.log                 # Update logs
    └── backup.log                 # Backup logs
```

## ⚡ Performance & Optimization

### 🚀 System Optimization

1.  **💾 Memory**: The script automatically sets up swap based on RAM
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

## 🐛 Troubleshooting Guide

### ❌ Common Errors & Solutions

**1. 🐳 Docker daemon not running (WSL)**

```bash
# Start Docker daemon
sudo dockerd &

# Or restart Docker service
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

**3. 🐳 Container does not start**

```bash
# View detailed logs
cd /home/n8n && docker-compose logs

# Cleanup and rebuild
docker system prune -f
cd /home/n8n && docker-compose down
docker-compose up -d --build

# If still an error, check ports
sudo netstat -tulpn | grep :80
sudo netstat -tulpn | grep :443
```

**4. 📰 News API authentication failed**

```bash
# Check token
grep NEWS_API_TOKEN /home/n8n/docker-compose.yml

# Test API health
curl -X GET "https://api.yourdomain.com/health" \
     -H "Authorization: Bearer YOUR_TOKEN"

# Restart News API service
cd /home/n8n && docker-compose restart fastapi
```

**5. 🔒 SSL Certificate issues**

```bash
# View Caddy logs
cd /home/n8n && docker-compose logs caddy

# Force SSL renewal
docker-compose restart caddy

# Check domain accessibility
curl -I https://yourdomain.com
```

**6. 📱 Telegram backup not working**

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

**7. 💾 Backup failed**

```bash
# Run a manual backup to debug
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
sudo ./auto_deploy_n8n.sh --clean

# 🔄 Soft restart services
cd /home/n8n
docker-compose restart

# 💾 Restore from backup
cd /home/n8n/files/backup_full
tar -xzf n8n_backup_YYYYMMDD_HHMMSS.tar.gz
# Copy files to the old location

# 🐳 Completely reset Docker
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
curl -I https://yourdomain.com                    # N8N
curl -I https://api.yourdomain.com/health        # News API
systemctl status docker                          # Docker
systemctl status cron                           # Cron jobs
```

## 🌟 Features Roadmap 2025

  - [ ] **🌍 Multi-domain** support for multiple N8N instances
  - [ ] **📊 Monitoring dashboard** with Grafana
  - [ ] **☸️ Kubernetes** deployment option
  - [ ] **🔗 External database** support (PostgreSQL)
  - [ ] **📈 Auto-scaling** based on load
  - [ ] **🛒 Plugin marketplace** integration
  - [ ] **🔔 Advanced notifications** (Discord, Slack, Email)
  - [ ] **🧠 AI content** analysis integration

## 🤝 Contributing & Support

### 💬 Get Support

  - **🐛 Issues**: [GitHub Issues](https://github.com/satriyabajuhitam/auto-n8n-complete/issues)
  - **🎥 YouTube**: [Kalvin Thien Social](https://www.youtube.com/@satriyabajuhitamsocial) - **SUBSCRIBE TO SUPPORT\!**
  - **📱 Whatsapp**: 628123456789

### 🔧 Contributing

1.  **🍴 Fork** this repository
2.  **🌿 Create a feature branch**: `git checkout -b feature/amazing-feature`
3.  **💾 Commit changes**: `git commit -m 'Add amazing feature'`
4.  **📤 Push to branch**: `git push origin feature/amazing-feature`
5.  **🔄 Create Pull Request**

### 📝 Bug Reports

When reporting a bug, please include:

  - **🖥️ OS version** (Ubuntu 20.04, 22.04, etc.)
  - **🐳 Docker version**
  - **📋 Error logs** from `docker-compose logs`
  - **🔧 Steps to reproduce**

## 📄 License & Credits

**📜 License**: MIT License - See [LICENSE](https://www.google.com/search?q=LICENSE) file

**🙏 Credits**:

  - **N8N Team** - Workflow automation platform
  - **📰 Newspaper4k** - Python article extraction
  - **🚀 FastAPI** - Modern Python web framework
  - **🐳 Docker** - Containerization platform
  - **🌐 Caddy** - Web server with automatic HTTPS

## ⭐ Star History & Community

> **🌟 If this script is helpful, give it a STAR to support\!**

### 📊 Statistics

## 🎯 Quick Links

| 🔗 Link | 📝 Description |
|---------|-----------|
| [📚 N8N Docs](https://docs.n8n.io/) | Official N8N documentation |
| [📰 Newspaper4k](https://pypi.org/project/newspaper4k/) | Python library for news scraping |
| [🚀 FastAPI](https://fastapi.tiangolo.com/) | Framework for News API |
| [🐳 Docker](https://docs.docker.com/) | Docker documentation |

-----
