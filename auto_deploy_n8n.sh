#!/bin/bash

# =============================================================================
# 🚀 AUTOMATED N8N INSTALLATION SCRIPT
# =============================================================================

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m' # No Color

# Global variables
INSTALL_DIR="/home/n8n"
DOMAIN=""
N8N_ENCRYPTION_KEY=""
TELEGRAM_BOT_TOKEN=""
TELEGRAM_CHAT_ID=""
RCLONE_REMOTE_NAME="gdrive_n8n"
GDRIVE_BACKUP_FOLDER="n8n_backups"
ENABLE_TELEGRAM=false
ENABLE_GDRIVE_BACKUP=false
ENABLE_AUTO_UPDATE=false
CLEAN_INSTALL=false
SKIP_DOCKER=false
RESTORE_MODE=false
RESTORE_SOURCE=""
RESTORE_FILE_PATH=""

# =============================================================================
# UTILITY FUNCTIONS
# =============================================================================

show_banner() {
    clear
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${WHITE}          🚀 AUTOMATED N8N INSTALLATION SCRIPT 2025 - PRODUCTION ONLY 🚀         ${CYAN}║${NC}"
    echo -e "${CYAN}╠══════════════════════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${CYAN}║${WHITE} ✨ N8N + FFmpeg + yt-dlp + Caddy SSL + Telegram/G-Drive Backup          ${CYAN}║${NC}"
    echo -e "${CYAN}║${WHITE} ✅ Refactored for simplicity, fixed proxy errors, and improved guides.       ${CYAN}║${NC}"
    echo -e "${CYAN}╠══════════════════════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${CYAN}║${YELLOW} 📅 Updated: 21/08/2025                                                 ${CYAN}║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

log() { echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] $1${NC}"; }
error() { echo -e "${RED}[ERROR] $1${NC}" >&2; }
warning() { echo -e "${YELLOW}[WARNING] $1${NC}"; }
info() { echo -e "${BLUE}[INFO] $1${NC}"; }
success() { echo -e "${GREEN}[SUCCESS] $1${NC}"; }

# =============================================================================
# ARGUMENT PARSING
# =============================================================================

show_help() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "This script installs N8N in Production Mode with a domain and SSL."
    echo ""
    echo "OPTIONS:"
    echo "  -h, --help          Display this help"
    echo "  -d, --dir DIR       Installation directory (default: /home/n8n)"
    echo "  -c, --clean         Delete old installation before starting"
    echo "  -s, --skip-docker   Skip Docker installation (if already installed)"
    echo ""
    echo "Example:"
    echo "  $0                  # Standard production installation"
    echo "  $0 --clean         # Delete old installation and install fresh"
    echo "  $0 -d /opt/n8n     # Install to /opt/n8n directory"
    echo ""
}

parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_help
                exit 0
                ;;
            -d|--dir)
                INSTALL_DIR="$2"
                shift 2
                ;;
            -c|--clean)
                CLEAN_INSTALL=true
                shift
                ;;
            -s|--skip-docker)
                SKIP_DOCKER=true
                shift
                ;;
            *)
                error "Invalid parameter: $1"
                show_help
                exit 1
                ;;
        esac
    done
}

# =============================================================================
# SYSTEM CHECKS
# =============================================================================

check_root() {
    if [[ $EUID -ne 0 ]]; then
        error "This script needs root privileges. Use: sudo $0"
        exit 1
    fi
}

check_os() {
    if [[ ! -f /etc/os-release ]]; then
        error "Cannot determine operating system."
        exit 1
    fi
    . /etc/os-release
    if [[ "$ID" != "ubuntu" ]]; then
        warning "This script is optimized for Ubuntu. Current OS: $ID"
        read -p "Do you want to continue anyway? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    fi
}

check_docker_compose() {
    if docker compose version &> /dev/null; then
        export DOCKER_COMPOSE="docker compose"
        info "Using 'docker compose' (v2)"
    elif command -v docker-compose &> /dev/null; then
        export DOCKER_COMPOSE="docker-compose"
        warning "'docker-compose' (v1) is detected. It's recommended to upgrade to the Docker Compose Plugin (v2)."
    else
        export DOCKER_COMPOSE=""
    fi
}

# =============================================================================
# SWAP MANAGEMENT
# =============================================================================

setup_swap() {
    log "🔄 Checking and setting up swap memory..."
    local ram_gb=$(free -g | awk '/^Mem:/{print $2}')
    local swap_size="4G" # Default to 4G for most cloud servers
    if [[ $ram_gb -le 2 ]]; then
        swap_size="2G"
    fi
    if swapon --show | grep -q "/swapfile"; then
        info "Swap file already exists. Skipping setup."
        return 0
    fi
    log "Creating ${swap_size} swap file..."
    fallocate -l $swap_size /swapfile || dd if=/dev/zero of=/swapfile bs=1024 count=$((${swap_size%G} * 1024 * 1024))
    chmod 600 /swapfile
    mkswap /swapfile
    swapon /swapfile
    if ! grep -q "/swapfile" /etc/fstab; then
        echo "/swapfile none swap sw 0 0" >> /etc/fstab
    fi
    success "Swap memory of ${swap_size} has been configured."
}

# =============================================================================
# RCLONE & RESTORE FUNCTIONS (IMPROVED GUIDE)
# =============================================================================

install_rclone() {
    if command -v rclone &> /dev/null; then
        info "rclone is already installed."
        return 0
    fi
    log "📦 Installing rclone..."
    apt-get update && apt-get install -y unzip curl
    curl https://rclone.org/install.sh | sudo bash
    success "rclone installed successfully."
}

setup_rclone_config() {
    if rclone listremotes | grep -q "^${RCLONE_REMOTE_NAME}:"; then
        info "rclone remote '${RCLONE_REMOTE_NAME}' already exists."
        return 0
    fi

    echo ""
    echo -e "${YELLOW}╔══════════════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${YELLOW}║${WHITE}            ⚙️ RCLONE + GOOGLE DRIVE CONFIGURATION GUIDE ⚙️             ${YELLOW}║${NC}"
    echo -e "${YELLOW}╚══════════════════════════════════════════════════════════════════════════════╝${NC}"
    echo "You are about to enter the rclone configuration wizard. Follow these instructions EXACTLY."
    echo ""
    echo -e "   The script will run ${CYAN}rclone config${NC}. Follow the interactive prompts:"
    echo ""
    echo -e "   1. When prompted ${WHITE}n/s/q> ${NC}, type ${GREEN}n${NC} and press [Enter] (for New remote)."
    echo ""
    echo -e "   2. When prompted for a ${WHITE}name> ${NC}, type this exact remote name:"
    echo -e "      ${RED}👉 ${RCLONE_REMOTE_NAME} ${NC}"
    echo -e "      (IMPORTANT: The name must be exact, then press [Enter])"
    echo ""
    echo -e "   3. You will see a list of cloud storage options. Look for ${WHITE}Google Drive${NC}."
    echo -e "      Type the corresponding number (e.g., ${GREEN}17${NC}) or type ${GREEN}drive${NC}, then press [Enter]."
    echo ""
    echo -e "   4. For ${WHITE}client_id> ${NC} and ${WHITE}client_secret> ${NC}, leave them blank. Just press [Enter] twice."
    echo ""
    echo -e "   5. For ${WHITE}scope> ${NC}, select full access. Type ${GREEN}1${NC} and press [Enter]."
    echo ""
    echo -e "   6. For ${WHITE}root_folder_id> ${NC} and ${WHITE}service_account_file> ${NC}, leave them blank. Just press [Enter] twice."
    echo ""
    echo -e "   7. When asked ${WHITE}Edit advanced config? (y/n)> ${NC}, type ${GREEN}n${NC} and press [Enter]."
    echo ""
    echo -e "   8. When asked ${WHITE}Use auto config? (y/n)> ${NC}, type ${RED}n${NC} and press [Enter]."
    echo -e "      ${YELLOW}(This is a crucial step when connecting via SSH).${NC}"
    echo ""
    echo -e "   9. Rclone will display an authorization link. ${CYAN}Copy this link${NC}."
    echo -e "      Open the link in your computer's browser, log in to your Google account, and grant permission."
    echo ""
    echo -e "  10. After granting permission, Google will provide a verification code in the browser."
    echo -e "      ${CYAN}Copy that code and paste it back into your terminal${NC}, then press [Enter]."
    echo ""
    echo -e "  11. When asked ${WHITE}Configure this as a team drive? (y/n)> ${NC}, type ${GREEN}n${NC} and press [Enter]."
    echo ""
    echo -e "  12. Confirm the settings. Type ${GREEN}y${NC} and press [Enter]."
    echo ""
    echo -e "  13. You will be back at the main menu. Type ${GREEN}q${NC} and press [Enter] to quit."
    echo ""
    read -p "Press [Enter] when you are ready to start 'rclone config'..."

    rclone config

    if ! rclone listremotes | grep -q "^${RCLONE_REMOTE_NAME}:"; then
        error "rclone remote configuration '${RCLONE_REMOTE_NAME}' failed. Please try again."
        exit 1
    fi
    success "rclone remote '${RCLONE_REMOTE_NAME}' configured successfully!"
}

get_restore_option() {
    echo ""
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${WHITE}                        🔄 DATA RESTORATION OPTION                          ${CYAN}║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    read -p "🔄 Do you want to restore data from an existing backup? (y/N): " -n 1 -r; echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        RESTORE_MODE=false
        return 0
    fi
    RESTORE_MODE=true
    echo "Select restore source:"
    echo -e "  ${GREEN}1. From a local backup file (.tar.gz)${NC}"
    echo -e "  ${GREEN}2. From Google Drive (requires rclone configuration)${NC}"
    read -p "Your choice [1]: " source_choice
    if [[ "$source_choice" == "2" ]]; then
        RESTORE_SOURCE="gdrive"
        install_rclone
        setup_rclone_config
        read -p "📝 Enter the folder name on Google Drive [${GDRIVE_BACKUP_FOLDER}]: " GDRIVE_FOLDER_INPUT
        if [[ -n "$GDRIVE_FOLDER_INPUT" ]]; then GDRIVE_BACKUP_FOLDER="$GDRIVE_FOLDER_INPUT"; fi
        log "🔍 Fetching backup list from Google Drive..."
        mapfile -t backups < <(rclone lsf "$RCLONE_REMOTE_NAME:$GDRIVE_BACKUP_FOLDER" --include "*.tar.gz" | sort -r)
        if [ ${#backups[@]} -eq 0 ]; then
            error "No backup files found in folder '$GDRIVE_BACKUP_FOLDER'."
            exit 1
        fi
        echo "Select the backup file to restore:"
        for i in "${!backups[@]}"; do
            echo "  $((i+1)). ${backups[$i]}"
        done
        read -p "Enter the file number: " file_idx
        selected_backup="${backups[$((file_idx-1))]}"
        if [[ -z "$selected_backup" ]]; then
            error "Invalid choice."
            exit 1
        fi
        log "📥 Downloading backup file '$selected_backup'..."
        mkdir -p /tmp/n8n_restore
        rclone copyto "$RCLONE_REMOTE_NAME:$GDRIVE_BACKUP_FOLDER/$selected_backup" "/tmp/n8n_restore/$selected_backup" --progress
        RESTORE_FILE_PATH="/tmp/n8n_restore/$selected_backup"
        success "Backup file downloaded successfully."
    else
        RESTORE_SOURCE="local"
        while true; do
            read -p "📁 Enter the full path to the backup file (.tar.gz): " RESTORE_FILE_PATH
            if [[ -f "$RESTORE_FILE_PATH" ]]; then break; else error "File not found."; fi
        done
    fi
    log "🔍 Verifying backup file integrity..."
    if ! tar -tzf "$RESTORE_FILE_PATH" &>/dev/null; then
        error "Backup file is corrupt or has the wrong format."
        exit 1
    fi
    success "Backup file is valid."
}

perform_restore() {
    if [[ "$RESTORE_MODE" != "true" ]]; then return 0; fi
    log "🔄 Starting restore process from: $RESTORE_FILE_PATH"
    mkdir -p "$INSTALL_DIR/files"
    log "🧹 Cleaning old data..."
    rm -rf "$INSTALL_DIR/files/"* 2>/dev/null || true
    log "📦 Extracting backup file..."
    local temp_extract_dir="/tmp/n8n_restore_extract_$$"
    mkdir -p "$temp_extract_dir"
    if tar -xzvf "$RESTORE_FILE_PATH" -C "$temp_extract_dir"; then
        local backup_content_dir
        if [[ -d "$temp_extract_dir/n8n_backup_"* ]]; then
            backup_content_dir=$(find "$temp_extract_dir" -maxdepth 1 -type d -name "n8n_backup_*" | head -1)
        elif [[ -d "$temp_extract_dir/credentials" ]]; then
            backup_content_dir="$temp_extract_dir"
        fi
        if [[ -n "$backup_content_dir" ]]; then
            log "Found backup content in: $backup_content_dir"
            if [[ -d "$backup_content_dir/credentials" ]]; then
                log "Restoring database and key..."
                cp -a "$backup_content_dir/credentials/"* "$INSTALL_DIR/files/" 2>/dev/null || true
            fi
            if [[ -f "$backup_content_dir/config/docker-compose.yml" ]]; then
                log "🔑 Extracting encryption key from backup..."
                local old_key=$(grep 'N8N_ENCRYPTION_KEY' "$backup_content_dir/config/docker-compose.yml" | head -n 1 | cut -d '=' -f2-)
                if [[ -n "$old_key" ]]; then
                    N8N_ENCRYPTION_KEY="$old_key"
                    info "Successfully extracted old encryption key."
                else
                    warning "Could not extract encryption key. This might cause issues with old credentials."
                fi
            fi
        else
            error "Invalid backup file structure."
            exit 1
        fi
        rm -rf "$temp_extract_dir"
        if [[ "$RESTORE_SOURCE" == "gdrive" ]]; then rm -rf "/tmp/n8n_restore"; fi
        chown -R 1000:1000 "$INSTALL_DIR/files/"
        success "✅ Data restored successfully!"
    else
        error "Failed to extract backup file."
        rm -rf "$temp_extract_dir"
        exit 1
    fi
}

# =============================================================================
# USER INPUT FUNCTIONS
# =============================================================================

get_domain_input() {
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${WHITE}                           🌐 DOMAIN CONFIGURATION                                ${CYAN}║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════════════════════╝${NC}"
    echo "This installation requires a domain with an A Record pointed to this server's IP address."
    while true; do
        read -p "🌐 Enter the main domain for N8N (e.g., n8n.domain.com): " DOMAIN
        if [[ -n "$DOMAIN" && "$DOMAIN" =~ ^[a-zA-Z0-9][a-zA-Z0-9.-]*[a-zA-Z0-9]$ ]]; then
            break
        else
            error "Invalid domain format. Please try again."
        fi
    done
    info "N8N will be installed on: ${DOMAIN}"
}

get_cleanup_option() {
    if [[ "$CLEAN_INSTALL" == "true" ]]; then return 0; fi
    if [[ -d "$INSTALL_DIR" ]]; then
        warning "An old N8N installation was detected at: $INSTALL_DIR"
        read -p "🗑️  Do you want to delete the old installation and start fresh? (y/N): " -n 1 -r; echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            CLEAN_INSTALL=true
        fi
    fi
}

get_backup_config() {
    echo ""
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${WHITE}                      💾 AUTOMATIC BACKUP CONFIGURATION                          ${CYAN}║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════════════════════╝${NC}"
    # Telegram Backup
    read -p "📱 Do you want to set up backup notifications via Telegram? (Y/n): " -n 1 -r; echo
    if [[ ! $REPLY =~ ^[Nn]$ ]]; then
        ENABLE_TELEGRAM=true
        info "To get your Token and Chat ID, follow the guides for BotFather and UserInfoBot on Telegram."
        while true; do read -p "🤖 Enter Telegram Bot Token: " TELEGRAM_BOT_TOKEN; if [[ -n "$TELEGRAM_BOT_TOKEN" ]]; then break; fi; done
        while true; do read -p "🆔 Enter Telegram Chat ID: " TELEGRAM_CHAT_ID; if [[ -n "$TELEGRAM_CHAT_ID" ]]; then break; fi; done
        success "Telegram Backup configured."
    fi
    # Google Drive Backup
    read -p "☁️ Do you want to set up backups to Google Drive? (Y/n): " -n 1 -r; echo
    if [[ ! $REPLY =~ ^[Nn]$ ]]; then
        ENABLE_GDRIVE_BACKUP=true
        install_rclone
        setup_rclone_config
        read -p "📝 Enter the folder name on Google Drive to store backups [${GDRIVE_BACKUP_FOLDER}]: " GDRIVE_FOLDER_INPUT
        if [[ -n "$GDRIVE_FOLDER_INPUT" ]]; then GDRIVE_BACKUP_FOLDER="$GDRIVE_FOLDER_INPUT"; fi
        success "Google Drive Backup configured."
    fi
}

get_auto_update_config() {
    echo ""
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${WHITE}                        🔄 N8N AUTO-UPDATE                                  ${CYAN}║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════════════════════╝${NC}"
    echo "This feature will automatically update N8N, back up before updating, and send notifications."
    read -p "🔄 Do you want to enable Auto-Update (every 12 hours)? (Y/n): " -n 1 -r; echo
    if [[ ! $REPLY =~ ^[Nn]$ ]]; then
        ENABLE_AUTO_UPDATE=true
        success "Auto-Update enabled."
    else
        ENABLE_AUTO_UPDATE=false
    fi
}

# =============================================================================
# DNS VERIFICATION
# =============================================================================

verify_dns() {
    log "🔍 Verifying DNS for domain ${DOMAIN}..."
    local server_ip=$(curl -s https://api.ipify.org || curl -s http://ipv4.icanhazip.com || echo "unknown")
    info "Your Server IP: ${server_ip}"
    local domain_ip=$(dig +short "$DOMAIN" A | tail -n1)
    info "Current IP for ${DOMAIN}: ${domain_ip:-"not found"}"
    if [[ "$domain_ip" != "$server_ip" ]]; then
        warning "The domain's DNS is not pointed to this server!"
        echo -e "${YELLOW}Please ensure you have an A Record in your DNS manager: ${DOMAIN} -> ${server_ip}${NC}"
        read -p "🤔 Continue with the installation? (SSL might fail) (y/N): " -n 1 -r; echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    else
        success "DNS verification successful."
    fi
}

# =============================================================================
# INSTALLATION & SETUP
# =============================================================================

cleanup_old_installation() {
    if [[ "$CLEAN_INSTALL" != "true" ]]; then return 0; fi
    log "🗑️ Deleting old installation..."
    if [[ -d "$INSTALL_DIR" ]]; then
        cd "$INSTALL_DIR"
        if [[ -n "$DOCKER_COMPOSE" ]]; then
            $DOCKER_COMPOSE down --volumes --remove-orphans 2>/dev/null || true
        fi
    fi
    rm -rf "$INSTALL_DIR"
    crontab -l 2>/dev/null | grep -v "$INSTALL_DIR" | crontab - 2>/dev/null || true
    success "Old installation deleted successfully."
}

install_docker() {
    if [[ "$SKIP_DOCKER" == "true" ]]; then info "Skipping Docker installation."; return 0; fi
    if command -v docker &> /dev/null; then
        info "Docker is already installed."
        if ! docker info &> /dev/null; then systemctl start docker && systemctl enable docker; fi
        if ! docker compose version &> /dev/null; then
            log "Installing Docker Compose Plugin (v2)..."
            apt-get update && apt-get install -y docker-compose-plugin
            export DOCKER_COMPOSE="docker compose"
        fi
        return 0
    fi
    log "📦 Installing Docker Engine..."
    apt-get update
    apt-get install -y apt-transport-https ca-certificates curl gnupg lsb-release
    install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    chmod a+r /etc/apt/keyrings/docker.gpg
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
    apt-get update
    apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    systemctl start docker && systemctl enable docker
    export DOCKER_COMPOSE="docker compose"
    success "Docker installed successfully."
}

create_project_structure() {
    log "📁 Creating project directory structure..."
    mkdir -p "$INSTALL_DIR"/{files/backup_full,files/temp,files/youtube_content_anylystic,logs}
    touch "$INSTALL_DIR"/logs/{backup.log,update.log,cron.log,health.log}
    success "Directory structure created at $INSTALL_DIR"
}

setup_env_file() {
    log "🔐 Setting up environment file (.env)..."
    if [[ -z "$N8N_ENCRYPTION_KEY" ]]; then
        if [[ -f "$INSTALL_DIR/.env" ]]; then
            info "Found existing .env file, loading encryption key."
            set -a; source "$INSTALL_DIR/.env"; set +a
        else
            info "Generating new encryption key."
            N8N_ENCRYPTION_KEY=$(openssl rand -hex 32)
        fi
    fi
    cat > "$INSTALL_DIR/.env" << EOF
# Environment Variables for N8N - Contains sensitive data.
# Do not delete. Back this up. Losing the key means losing credential data.
N8N_ENCRYPTION_KEY=${N8N_ENCRYPTION_KEY}
GENERIC_TIMEZONE=Asia/Jakarta
EOF
    chmod 600 "$INSTALL_DIR/.env"
    success ".env file created and secured successfully."
}

create_dockerfile() {
    log "🐳 Creating Dockerfile for N8N (with FFmpeg & yt-dlp)..."
    cat > "$INSTALL_DIR/Dockerfile" << 'EOF'
FROM n8nio/n8n:latest
USER root
RUN apk update && apk add --no-cache ffmpeg python3 py3-pip && rm -rf /var/cache/apk/*
RUN pip3 install --no-cache-dir --break-system-packages yt-dlp
RUN mkdir -p /home/node/.n8n/nodes /data/youtube_content_anylystic && \
    chown -R 1000:1000 /home/node/.n8n /data
USER node
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD curl -f http://localhost:5678/healthz || exit 1
WORKDIR /data
EOF
    success "Dockerfile created successfully."
}

create_docker_compose() {
    log "🐳 Creating docker-compose.yml file..."
    cat > "$INSTALL_DIR/docker-compose.yml" << EOF
version: '3.8'

services:
  n8n:
    build:
      context: .
      pull: true
    container_name: n8n-container
    restart: unless-stopped
    ports:
      - "127.0.0.1:5678:5678"
    env_file:
      - .env
    environment:
      N8N_HOST: "0.0.0.0"
      N8N_PORT: "5678"
      N8N_PROTOCOL: "https"
      WEBHOOK_URL: "https://${DOMAIN}/"
      NODE_ENV: "production"
      N8N_METRICS: "true"
      N8N_USER_FOLDER: "/home/node"
      DB_TYPE: "sqlite"
      DB_SQLITE_DATABASE: "/home/node/.n8n/database.sqlite"
      EXECUTIONS_TIMEOUT: "3600"
      NODE_FUNCTION_ALLOW_BUILTIN: "child_process,path,fs,util,os"
      N8N_TRUSTED_PROXIES: "caddy"
      N8N_USE_X_FORWARDED_HEADERS: "true" # Fix for proxy validation error
    volumes:
      - ./files:/home/node/.n8n
      - ./files/youtube_content_anylystic:/data/youtube_content_anylystic
      - /var/run/docker.sock:/var/run/docker.sock:ro
    networks:
      - n8n_network

  caddy:
    image: caddy:latest
    container_name: caddy-proxy
    restart: unless-stopped
    ports:
      - "80:80"
      - "443:443"
      - "443:443/udp"
    volumes:
      - ./Caddyfile:/etc/caddy/Caddyfile
      - caddy_data:/data
      - caddy_config:/config
    networks:
      - n8n_network
    depends_on:
      - n8n

volumes:
  caddy_data:
  caddy_config:

networks:
  n8n_network:
    driver: bridge
EOF
    success "docker-compose.yml created successfully."
}

create_caddyfile() {
    log "🌐 Creating Caddy configuration file (Caddyfile)..."
    cat > "$INSTALL_DIR/Caddyfile" << EOF
{
    email admin@${DOMAIN}
    acme_ca https://acme-v02.api.letsencrypt.org/directory
}
${DOMAIN} {
    reverse_proxy n8n:5678
    header {
        Strict-Transport-Security "max-age=31536000;"
        X-Content-Type-Options "nosniff"
        X-Frame-Options "DENY"
    }
    encode gzip
    log {
        output file /var/log/caddy/n8n.log
        format json
    }
}
EOF
    success "Caddyfile created successfully."
}

# =============================================================================
# HELPER SCRIPTS (Backup, Update, etc.)
# =============================================================================

create_backup_scripts() {
    log "💾 Creating backup scripts..."
    cat > "$INSTALL_DIR/backup-workflows.sh" << 'EOF'
#!/bin/bash
set -e
BACKUP_DIR="/home/n8n/files/backup_full"
LOG_FILE="/home/n8n/logs/backup.log"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
BACKUP_NAME="n8n_backup_$TIMESTAMP"
TEMP_DIR="/tmp/$BACKUP_NAME"
log() { echo "[$(date +'%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"; }
mkdir -p "$BACKUP_DIR" "$TEMP_DIR/credentials" "$TEMP_DIR/config"
log "🔄 Starting N8N backup..."
cp "/home/n8n/files/database.sqlite" "$TEMP_DIR/credentials/"
cp "/home/n8n/.env" "$TEMP_DIR/config/"
log "📦 Compressing backup file..."
cd /tmp && tar -czf "$BACKUP_DIR/$BACKUP_NAME.tar.gz" "$BACKUP_NAME/"
BACKUP_SIZE=$(ls -lh "$BACKUP_DIR/$BACKUP_NAME.tar.gz" | awk '{print $5}')
log "✅ Backup complete: $BACKUP_NAME.tar.gz ($BACKUP_SIZE)"
rm -rf "$TEMP_DIR"
log "🧹 Cleaning up old local backups (keeping last 30)..."
ls -t "$BACKUP_DIR"/n8n_backup_*.tar.gz 2>/dev/null | tail -n +31 | xargs -r rm -f
if [[ -f "/home/n8n/telegram_config.txt" ]]; then
    source "/home/n8n/telegram_config.txt"
    MESSAGE="🔄 *N8N Backup Completed*\nFile: \`$BACKUP_NAME.tar.gz\`\nSize: $BACKUP_SIZE"
    curl -s -X POST "https://api.telegram.org/bot$TELEGRAM_BOT_TOKEN/sendMessage" -d chat_id="$TELEGRAM_CHAT_ID" -d text="$MESSAGE" -d parse_mode="Markdown" > /dev/null
fi
if [[ -f "/home/n8n/gdrive_config.txt" ]]; then
    source "/home/n8n/gdrive_config.txt"
    log "☁️ Uploading to Google Drive..."
    rclone copy "$BACKUP_DIR/$BACKUP_NAME.tar.gz" "$RCLONE_REMOTE_NAME:$GDRIVE_BACKUP_FOLDER" --progress
    log "🧹 Cleaning up old Google Drive backups (older than 30 days)..."
    rclone delete --min-age 30d "$RCLONE_REMOTE_NAME:$GDRIVE_BACKUP_FOLDER"
fi
log "🎉 Backup process finished."
EOF
    chmod +x "$INSTALL_DIR/backup-workflows.sh"
    # Manual backup script
    cat > "$INSTALL_DIR/backup-manual.sh" << 'EOF'
#!/bin/bash
echo "Running manual backup..."
/home/n8n/backup-workflows.sh
echo "Done. Check logs at /home/n8n/logs/backup.log and files at /home/n8n/files/backup_full"
EOF
    chmod +x "$INSTALL_DIR/backup-manual.sh"
    success "Backup scripts created successfully."
}

create_update_script() {
    log "🔄 Creating auto-update script..."
    cat > "$INSTALL_DIR/update-n8n.sh" << 'EOF'
#!/bin/bash
set -e
LOG_FILE="/home/n8n/logs/update.log"
log() { echo "[$(date)] $1" | tee -a "$LOG_FILE"; }
send_telegram() { if [[ -f "/home/n8n/telegram_config.txt" ]]; then source "/home/n8n/telegram_config.txt"; curl -s -X POST "https://api.telegram.org/bot$TELEGRAM_BOT_TOKEN/sendMessage" -d chat_id="$TELEGRAM_CHAT_ID" -d text="$1" -d parse_mode="Markdown" > /dev/null; fi; }
cd /home/n8n
log "🔄 Starting N8N auto-update..."
log "💾 Backing up before update..."
./backup-workflows.sh
log "📦 Pulling latest Docker images..."
docker compose pull
log "🚀 Restarting containers..."
docker compose up -d --remove-orphans
log "🧹 Pruning old images..."
docker image prune -f
log "🎉 Update process finished."
send_telegram "✅ *N8N Auto-Update Successful*\nN8N has been updated to the latest version."
EOF
    chmod +x "$INSTALL_DIR/update-n8n.sh"
    success "Auto-update script created successfully."
}

create_health_monitor() {
    log "🏥 Creating health monitor script..."
    cat > "$INSTALL_DIR/health-monitor.sh" << 'EOF'
#!/bin/bash
LOG_FILE="/home/n8n/logs/health.log"
TIMESTAMP=$(date +"%Y-%m-%d %H:%M:%S")
N8N_HEALTH=$(curl -s -o /dev/null -w "%{http_code}" http://127.0.0.1:5678/healthz || echo "000")
N8N_STATUS=$(docker inspect -f '{{.State.Status}}' n8n-container 2>/dev/null || echo "not_found")
echo "[$TIMESTAMP] Health: $N8N_HEALTH, Container: $N8N_STATUS" >> "$LOG_FILE"
if [[ "$N8N_HEALTH" != "200" ]] || [[ "$N8N_STATUS" != "running" ]]; then
    echo "[$TIMESTAMP] N8N is unhealthy! Attempting restart..." >> "$LOG_FILE"
    cd /home/n8n && docker compose restart n8n
    if [[ -f "/home/n8n/telegram_config.txt" ]]; then
        source "/home/n8n/telegram_config.txt"
        MESSAGE="⚠️ *N8N Health Alert*\nStatus: Unhealthy (Code: $N8N_HEALTH, Status: $N8N_STATUS)\nAttempting an automatic restart."
        curl -s -X POST "https://api.telegram.org/bot$TELEGRAM_BOT_TOKEN/sendMessage" -d chat_id="$TELEGRAM_CHAT_ID" -d text="$MESSAGE" -d parse_mode="Markdown" > /dev/null
    fi
fi
EOF
    chmod +x "$INSTALL_DIR/health-monitor.sh"
    success "Health monitor script created."
}

create_troubleshooting_script() {
    log "🔧 Creating troubleshooting script..."
    cat > "$INSTALL_DIR/troubleshoot.sh" << 'EOF'
#!/bin/bash
CYAN='\033[0;36m'; WHITE='\033[1;37m'; NC='\033[0m'; BLUE='\033[0;34m';
echo -e "${CYAN}╔══════════════════ 🔧 N8N TROUBLESHOOTING 🔧 ══════════════════╗${NC}\n"
cd /home/n8n
DOMAIN=$(grep -E "^[a-zA-Z0-9.-]+\s*{" Caddyfile | head -1 | awk '{print $1}')
echo -e "${BLUE}📍 System & Docker Info:${NC}"
echo " • OS: $(lsb_release -ds)"
echo " • Docker: $(docker --version)"
echo " • Docker Compose: $(docker compose version)"
echo -e "\n${BLUE}📍 Container Status:${NC}"; docker compose ps
echo -e "\n${BLUE}📍 Installation Info:${NC}"
echo " • Mode: Production (SSL)"
echo " • Domain: $DOMAIN"
echo -e "\n${BLUE}📍 SSL & DNS Status:${NC}"
echo " • DNS Resolution: $(dig +short $DOMAIN A | tail -1)"
echo " • SSL Test: $(timeout 5 curl -Is https://$DOMAIN 2>/dev/null | head -1 || echo 'Connection failed')"
echo -e "\n${BLUE}📍 Last 10 Error/Warn Logs (N8N):${NC}"
docker compose logs n8n 2>&1 | grep -iE "(error|warn)" | tail -10 || echo " No errors or warnings found."
echo -e "\n${CYAN}╚════════════════════════════════════════════════════════════════╝${NC}"
EOF
    chmod +x "$INSTALL_DIR/troubleshoot.sh"
    success "Troubleshooting script created."
}

# =============================================================================
# FINALIZATION
# =============================================================================

setup_backup_configs() {
    if [[ "$ENABLE_TELEGRAM" == "true" ]]; then
        log "📱 Saving Telegram configuration..."
        echo "TELEGRAM_BOT_TOKEN=\"$TELEGRAM_BOT_TOKEN\"" > "$INSTALL_DIR/telegram_config.txt"
        echo "TELEGRAM_CHAT_ID=\"$TELEGRAM_CHAT_ID\"" >> "$INSTALL_DIR/telegram_config.txt"
        chmod 600 "$INSTALL_DIR/telegram_config.txt"
    fi
    if [[ "$ENABLE_GDRIVE_BACKUP" == "true" ]]; then
        log "☁️ Saving Google Drive configuration..."
        echo "RCLONE_REMOTE_NAME=\"$RCLONE_REMOTE_NAME\"" > "$INSTALL_DIR/gdrive_config.txt"
        echo "GDRIVE_BACKUP_FOLDER=\"$GDRIVE_BACKUP_FOLDER\"" >> "$INSTALL_DIR/gdrive_config.txt"
        chmod 600 "$INSTALL_DIR/gdrive_config.txt"
    fi
}

setup_cron_jobs() {
    log "⏰ Setting up cron jobs..."
    (crontab -l 2>/dev/null | grep -v "$INSTALL_DIR") | crontab -
    (crontab -l 2>/dev/null; echo "0 2 * * * $INSTALL_DIR/backup-workflows.sh >> $INSTALL_DIR/logs/cron.log 2>&1") | crontab -
    if [[ "$ENABLE_AUTO_UPDATE" == "true" ]]; then
        (crontab -l 2>/dev/null; echo "0 */12 * * * $INSTALL_DIR/update-n8n.sh >> $INSTALL_DIR/logs/cron.log 2>&1") | crontab -
    fi
    (crontab -l 2>/dev/null; echo "*/5 * * * * $INSTALL_DIR/health-monitor.sh >> $INSTALL_DIR/logs/cron.log 2>&1") | crontab -
    log "Configured cron jobs:"
    crontab -l | grep "$INSTALL_DIR"
    success "Cron jobs set up successfully."
}

build_and_deploy() {
    log "🏗️ Building and deploying containers..."
    cd "$INSTALL_DIR"
    log "🔐 Setting permissions for data directory..."
    chown -R 1000:1000 "$INSTALL_DIR/files/"
    log "📦 Building Docker image (this might take a few minutes)..."
    $DOCKER_COMPOSE build --no-cache
    log "🚀 Starting all services..."
    $DOCKER_COMPOSE up -d
    log "⏳ Waiting for services to become healthy (max 3 minutes)..."
    sleep 15 # Give some initial time for containers to start
    local max_retries=12; local attempt=0
    while [[ $attempt -lt $max_retries ]]; do
        n8n_health=$(docker inspect --format='{{.State.Health.Status}}' n8n-container 2>/dev/null)
        caddy_status=$(docker inspect --format='{{.State.Status}}' caddy-proxy 2>/dev/null)
        if [[ "$n8n_health" == "healthy" && "$caddy_status" == "running" ]]; then
            success "🎉 All services are up and healthy!"
            return 0
        fi
        ((attempt++)); echo "   ... Check #${attempt}/${max_retries}: N8N ($n8n_health), Caddy ($caddy_status)"; sleep 15
    done
    error "One or more services failed to start correctly after 3 minutes."
    $DOCKER_COMPOSE ps
    $DOCKER_COMPOSE logs --tail=50
    exit 1
}

check_ssl() {
    log "🔒 Verifying SSL certificate issuance (max 2 minutes)..."
    local max_retries=12; local attempt=0;
    while [[ $attempt -lt $max_retries ]]; do
        if $DOCKER_COMPOSE logs caddy 2>&1 | grep -q "certificate obtained successfully"; then
            success "✅ SSL certificate for ${DOMAIN} was issued successfully."
            return 0
        fi
        if $DOCKER_COMPOSE logs caddy 2>&1 | grep -q "urn:ietf:params:acme:error:rateLimited"; then
            error "🚨 SSL RATE LIMIT DETECTED!"
            warning "You have requested certificates for this domain too many times."
            warning "Try again in a few hours or a week. N8N will be inaccessible until then."
            return 1
        fi
        ((attempt++)); echo "   ... Waiting for SSL status (attempt ${attempt}/${max_retries})"; sleep 10
    done
    warning "Could not confirm SSL status. Please check Caddy logs manually: docker compose -f ${INSTALL_DIR}/docker-compose.yml logs caddy"
}

show_final_summary() {
    clear
    echo -e "${GREEN}╔══════════════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║${WHITE}                    🎉 N8N INSTALLATION SUCCESSFUL! 🎉                   ${GREEN}║${NC}"
    echo -e "${GREEN}╚══════════════════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${CYAN}🌐 ACCESS YOUR N8N INSTANCE AT:${NC}"
    echo -e "   ${WHITE}https://${DOMAIN}${NC}"
    echo ""
    echo -e "${CYAN}📁 SYSTEM INFORMATION:${NC}"
    echo -e " • Installation Directory: ${WHITE}${INSTALL_DIR}${NC}"
    echo -e " • Secrets File:           ${WHITE}${INSTALL_DIR}/.env (Keep this file safe!)${NC}"
    echo -e " • Diagnostics Script:     ${WHITE}bash ${INSTALL_DIR}/troubleshoot.sh${NC}"
    echo ""
    echo -e "${CYAN}💾 BACKUP & UPDATE CONFIGURATION:${NC}"
    echo -e " • Automatic Backup:       ${WHITE}Daily at 2:00 AM${NC}"
    echo -e " • Backup Location:        ${WHITE}${INSTALL_DIR}/files/backup_full/${NC}"
    echo -e " • Auto-Update:            ${WHITE}$([[ "$ENABLE_AUTO_UPDATE" == "true" ]] && echo "Enabled (every 12h)" || echo "Disabled")${NC}"
    echo -e " • Health Check:           ${WHITE}Every 5 minutes${NC}"
    echo ""
    echo -e "${CYAN}📋 USEFUL COMMANDS:${NC}"
    echo -e " • View Logs:              ${WHITE}cd ${INSTALL_DIR} && docker compose logs -f${NC}"
    echo -e " • Restart Services:       ${WHITE}cd ${INSTALL_DIR} && docker compose restart${NC}"
    echo -e " • Manual Backup:          ${WHITE}bash ${INSTALL_DIR}/backup-manual.sh${NC}"
    echo -e " • Manual Update:          ${WHITE}bash ${INSTALL_DIR}/update-n8n.sh${NC}"
    echo ""
    echo -e "${YELLOW}Thank you for using this script!${NC}"
    echo -e "${GREEN}╚══════════════════════════════════════════════════════════════════════════════╝${NC}"
}

# =============================================================================
# MAIN EXECUTION
# =============================================================================

main() {
    parse_arguments "$@"
    show_banner
    check_root
    check_os
    check_docker_compose
    setup_swap
    get_restore_option
    get_domain_input
    get_cleanup_option
    get_backup_config
    get_auto_update_config
    verify_dns
    cleanup_old_installation
    install_docker
    create_project_structure
    perform_restore
    setup_env_file
    create_dockerfile
    create_docker_compose
    create_caddyfile
    create_backup_scripts
    create_update_script
    create_health_monitor
    create_troubleshooting_script
    setup_backup_configs
    setup_cron_jobs
    build_and_deploy
    check_ssl
    show_final_summary
}

main "$@"
