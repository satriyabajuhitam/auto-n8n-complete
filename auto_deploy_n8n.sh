#!/bin/bash

# =============================================================================
# 🚀 AUTOMATED N8N INSTALLATION SCRIPT 2025 - FINAL FIXED VERSION
# =============================================================================

set -e

# --- Colors for output ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m'

# --- Global Variables ---
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
LOCAL_MODE=false
RESTORE_MODE=false
RESTORE_FILE_PATH=""

# =============================================================================
# >> UTILITY FUNCTIONS
# =============================================================================
show_banner() {
    clear
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${WHITE}        🚀 AUTOMATED N8N INSTALLATION SCRIPT 2025 (FINAL FIXED VERSION) 🚀     ${CYAN}║${NC}"
    echo -e "${CYAN}╠══════════════════════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${CYAN}║${WHITE} ✨ Features: N8N + FFmpeg + yt-dlp + Telegram/G-Drive Backup              ${CYAN}║${NC}"
    echo -e "${CYAN}║${WHITE} ✅ Fixes: Security, Health Check Stability, and Modern Configuration       ${CYAN}║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

log() { echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] $1${NC}"; }
error() { echo -e "${RED}[ERROR] $1${NC}" >&2; }
warning() { echo -e "${YELLOW}[WARNING] $1${NC}"; }
info() { echo -e "${BLUE}[INFO] $1${NC}"; }
success() { echo -e "${GREEN}[SUCCESS] $1${NC}"; }

# =============================================================================
# >> ARGUMENT PARSING
# =============================================================================
show_help() {
    echo "Usage: $0 [OPTIONS]"
    echo "OPTIONS:"
    echo "  -h, --help          Display this help"
    echo "  -d, --dir DIR       Installation directory (default: /home/n8n)"
    echo "  -c, --clean         Delete old installation before starting"
    echo "  -s, --skip-docker   Skip Docker installation (if it already exists)"
    echo "  -l, --local         Install in Local Mode (no domain needed)"
}

parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help) show_help; exit 0;;
            -d|--dir) INSTALL_DIR="$2"; shift 2;;
            -c|--clean) CLEAN_INSTALL=true; shift;;
            -s|--skip-docker) SKIP_DOCKER=true; shift;;
            -l|--local) LOCAL_MODE=true; shift;;
            *) error "Invalid parameter: $1"; show_help; exit 1;;
        esac
    done
}

# =============================================================================
# >> SYSTEM CHECKS
# =============================================================================
check_root() {
    if [[ $EUID -ne 0 ]]; then
        error "This script must be run with root privileges. Use: sudo $0"
        exit 1
    fi
}

check_docker_compose() {
    if docker compose version &>/dev/null; then
        export DOCKER_COMPOSE="docker compose"
    elif command -v docker-compose &>/dev/null; then
        export DOCKER_COMPOSE="docker-compose"
    else
        export DOCKER_COMPOSE=""
    fi
}

# =============================================================================
# >> RESTORE & RCLONE MANAGEMENT
# =============================================================================
install_rclone() {
    if command -v rclone &>/dev/null; then info "rclone is already installed."; return 0; fi
    log "📦 Installing rclone..."
    apt-get update >/dev/null && apt-get install -y unzip curl >/dev/null
    curl -s https://rclone.org/install.sh | sudo bash
    success "rclone installed successfully."
}

setup_rclone_config() {
    if rclone listremotes | grep -q "^${RCLONE_REMOTE_NAME}:"; then info "rclone remote '${RCLONE_REMOTE_NAME}' already exists."; return 0; fi
    echo -e "\n${YELLOW}--- RCLONE + GOOGLE DRIVE CONFIGURATION GUIDE ---${NC}"
    echo "You are about to enter the rclone config wizard. Follow these instructions EXACTLY."
    echo "1. Select 'n' (New remote)."
    echo "2. Enter the remote name: '${RCLONE_REMOTE_NAME}'"
    echo "3. Select the number for 'drive' (Google Drive)."
    echo "4. Press Enter for 'client_id' and 'client_secret' (leave blank)."
    echo "5. Select '1' for 'scope' (Full access)."
    echo "6. Press Enter for 'root_folder_id' and 'service_account_file'."
    echo "7. Select 'n' for 'Edit advanced config?'."
    echo "8. ${RED}IMPORTANT:${NC} Select 'n' for 'Use auto config?' (if you are using SSH)."
    echo "9. Copy the link shown, open it in your browser, authorize, then copy the verification code."
    echo "10. Paste the verification code back into the terminal."
    echo "11. Select 'n' for 'Configure this as a team drive?'."
    echo "12. Confirm with 'y', then quit with 'q'."
    read -p "Press [Enter] when you are ready to start 'rclone config'..."
    rclone config
    if ! rclone listremotes | grep -q "^${RCLONE_REMOTE_NAME}:"; then error "rclone configuration failed."; exit 1; fi
    success "rclone remote '${RCLONE_REMOTE_NAME}' configured successfully!"
}

get_restore_option() {
    read -p "🔄 Do you want to restore data from a backup? (y/N): " -n 1 -r; echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then return 0; fi
    RESTORE_MODE=true
}

perform_restore() {
    if [[ ! "$RESTORE_MODE" == "true" ]]; then return 0; fi
    log "🔄 Starting restore process from: $RESTORE_FILE_PATH"
    
    if tar -xOzf "$RESTORE_FILE_PATH" "n8n_backup_*/config/.env" 2>/dev/null | grep 'N8N_ENCRYPTION_KEY' > /tmp/restored_key.txt; then
        local old_key=$(cut -d '=' -f2- /tmp/restored_key.txt)
        if [[ -n "$old_key" ]]; then
            N8N_ENCRYPTION_KEY="$old_key"
            info "🔑 Successfully extracted encryption key from backup file."
        fi
        rm /tmp/restored_key.txt
    fi
}

# =============================================================================
# >> MAIN INSTALLATION FUNCTIONS
# =============================================================================
get_user_input() {
    if [[ "$LOCAL_MODE" == "false" ]]; then
        while true; do
            read -p "🌐 Enter the main domain for N8N (e.g., n8n.domain.com): " DOMAIN
            if [[ -n "$DOMAIN" ]]; then break; else error "Domain cannot be empty."; fi
        done
    fi
    get_backup_config
    get_auto_update_config
}

get_backup_config() {
    if [[ "$LOCAL_MODE" == "true" ]]; then return 0; fi
    read -p "📱 Set up backup notifications via Telegram? (y/N): " -n 1 -r; echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        ENABLE_TELEGRAM=true
        read -p "🤖 Enter Telegram Bot Token: " TELEGRAM_BOT_TOKEN
        read -p "🆔 Enter Telegram Chat ID: " TELEGRAM_CHAT_ID
    fi
    read -p "☁️ Set up backup to Google Drive? (y/N): " -n 1 -r; echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        ENABLE_GDRIVE_BACKUP=true
        install_rclone
        setup_rclone_config
    fi
}

get_auto_update_config() {
    if [[ "$LOCAL_MODE" == "true" ]]; then return 0; fi
    read -p "🔄 Enable Auto-Update (every 12 hours)? (y/N): " -n 1 -r; echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then ENABLE_AUTO_UPDATE=true; fi
}

cleanup_old_installation() {
    if [[ ! "$CLEAN_INSTALL" == "true" ]]; then return 0; fi
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
    if command -v docker &>/dev/null; then info "Docker is already installed."; return 0; fi
    log "📦 Installing Docker Engine..."
    apt-get update -y >/dev/null
    apt-get install -y apt-transport-https ca-certificates curl gnupg lsb-release >/dev/null
    install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    chmod a+r /etc/apt/keyrings/docker.gpg
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
    apt-get update -y >/dev/null
    apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin >/dev/null
    systemctl start docker && systemctl enable docker
    success "Docker installed successfully."
}

# --- CONFIGURATION FILE CREATION ---
setup_env_file() {
    log "🔐 Creating secure environment file (.env)..."
    if [[ -z "$N8N_ENCRYPTION_KEY" ]]; then
        if [[ -f "$INSTALL_DIR/.env" ]] && grep -q "N8N_ENCRYPTION_KEY" "$INSTALL_DIR/.env"; then
            info "Loading existing encryption key from .env file."
            N8N_ENCRYPTION_KEY=$(grep "N8N_ENCRYPTION_KEY" "$INSTALL_DIR/.env" | cut -d '=' -f2-)
        else
            info "Generating a new encryption key."
            N8N_ENCRYPTION_KEY=$(openssl rand -hex 32)
        fi
    fi
    
    cat > "$INSTALL_DIR/.env" << EOF
# This file contains sensitive variables. Keep it secret.
# This encryption key is VERY IMPORTANT. Losing it means losing all credentials.
N8N_ENCRYPTION_KEY=${N8N_ENCRYPTION_KEY}
GENERIC_TIMEZONE=Asia/Jakarta
EOF
    chmod 600 "$INSTALL_DIR/.env"
    success ".env file created and secured successfully."
}

create_dockerfile() {
    log "🐳 Creating Dockerfile..."
    cat > "$INSTALL_DIR/Dockerfile" << 'EOF'
FROM n8nio/n8n:latest

USER root
RUN apk update && apk add --no-cache ffmpeg python3 py3-pip && rm -rf /var/cache/apk/*
RUN pip3 install --no-cache-dir --break-system-packages yt-dlp
USER node

# FIX: Changed localhost to 127.0.0.1 for reliability
HEALTHCHECK --interval=30s --timeout=10s --start-period=90s --retries=3 \
    CMD curl -f http://127.0.0.1:5678/healthz || exit 1
EOF
    success "Dockerfile created successfully."
}

create_docker_compose() {
    log "🐳 Creating docker-compose.yml file..."
    local compose_content
    if [[ "$LOCAL_MODE" == "true" ]]; then
        compose_content=$(cat <<EOF
services:
  n8n:
    build: .
    container_name: n8n-container
    restart: unless-stopped
    ports:
      - "5678:5678"
    env_file: .env
    environment:
      # --- Modern Config for Performance & Stability ---
      N8N_ENFORCE_SETTINGS_FILE_PERMISSIONS: "true"
      DB_SQLITE_POOL_SIZE: "10"
      N8N_RUNNERS_ENABLED: "true"
      # --- Basic Config ---
      WEBHOOK_URL: "http://localhost:5678/"
    volumes:
      - ./files:/home/node/.n8n
networks:
  n8n_network:
EOF
)
    else
        compose_content=$(cat <<EOF
services:
  n8n:
    build: .
    container_name: n8n-container
    restart: unless-stopped
    ports:
      - "127.0.0.1:5678:5678"
    env_file: .env
    environment:
      # --- Modern Config for Performance & Stability ---
      N8N_ENFORCE_SETTINGS_FILE_PERMISSIONS: "true"
      DB_SQLITE_POOL_SIZE: "10"
      N8N_RUNNERS_ENABLED: "true"
      # --- Basic Config ---
      WEBHOOK_URL: "https://${DOMAIN}/"
    volumes:
      - ./files:/home/node/.n8n
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

volumes:
  caddy_data:
  caddy_config:
EOF
)
    fi
    echo "$compose_content" > "$INSTALL_DIR/docker-compose.yml"
    echo "networks:\n  n8n_network:\n    driver: bridge" >> "$INSTALL_DIR/docker-compose.yml"
    success "docker-compose.yml created successfully."
}

create_caddyfile() {
    if [[ "$LOCAL_MODE" == "true" ]]; then return 0; fi
    log "🌐 Creating Caddyfile..."
    cat > "$INSTALL_DIR/Caddyfile" << EOF
${DOMAIN} {
    reverse_proxy n8n:5678
}
EOF
    success "Caddyfile created successfully."
}

# --- HELPER SCRIPT CREATION ---
create_helper_scripts() {
    log "💾 Creating helper scripts (backup, update, troubleshoot)..."
    # Backup script
    cat > "$INSTALL_DIR/backup.sh" << 'EOF'
#!/bin/bash
set -e
BACKUP_DIR="/home/n8n/files/backup_full"
LOG_FILE="/home/n8n/logs/backup.log"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
BACKUP_NAME="n8n_backup_$TIMESTAMP"
TEMP_DIR="/tmp/$BACKUP_NAME"
log() { echo "[$(date)] $1" | tee -a "$LOG_FILE"; }
mkdir -p "$BACKUP_DIR" "$TEMP_DIR/config" "$TEMP_DIR/credentials"
log "🔄 Starting backup..."
cp "/home/n8n/files/database.sqlite" "$TEMP_DIR/credentials/"
cp "/home/n8n/.env" "$TEMP_DIR/config/"
cd /tmp && tar -czf "$BACKUP_DIR/$BACKUP_NAME.tar.gz" "$BACKUP_NAME/"
rm -rf "$TEMP_DIR"
log "✅ Backup complete: $BACKUP_NAME.tar.gz"
ls -t "$BACKUP_DIR"/n8n_backup_*.tar.gz | tail -n +31 | xargs -r rm -f
if [[ -f "/home/n8n/gdrive_config.txt" ]]; then
    source "/home/n8n/gdrive_config.txt"
    log "☁️ Uploading to Google Drive..."
    rclone copy "$BACKUP_DIR/$BACKUP_NAME.tar.gz" "$RCLONE_REMOTE_NAME:$GDRIVE_BACKUP_FOLDER"
fi
EOF
    # Update script
    cat > "$INSTALL_DIR/update.sh" << 'EOF'
#!/bin/bash
set -e
cd /home/n8n
echo "🔄 Starting update..."
./backup.sh
docker compose pull
docker compose up -d --build
docker image prune -f
echo "✅ Update complete."
EOF
    # Troubleshoot script
    cat > "$INSTALL_DIR/troubleshoot.sh" << 'EOF'
#!/bin/bash
echo "--- 🔧 N8N TROUBLESHOOTING 🔧 ---"
cd /home/n8n
echo "📍 Container Status:"
docker compose ps
echo -e "\n📍 N8N Logs (last 15 lines):"
docker compose logs n8n | tail -n 15
echo -e "\n📍 Caddy Logs (last 15 lines):"
docker compose logs caddy | tail -n 15
echo "---------------------------------"
EOF
    chmod +x "$INSTALL_DIR"/{backup.sh,update.sh,troubleshoot.sh}
    success "Helper scripts created successfully."
}

# =============================================================================
# >> FINALIZATION & DEPLOY
# =============================================================================
setup_cron_jobs() {
    if [[ "$LOCAL_MODE" == "true" ]]; then return 0; fi
    log "⏰ Setting up cron jobs..."
    (crontab -l 2>/dev/null | grep -v "$INSTALL_DIR") | crontab -
    (crontab -l 2>/dev/null; echo "0 2 * * * $INSTALL_DIR/backup.sh >> $INSTALL_DIR/logs/cron.log 2>&1") | crontab -
    if [[ "$ENABLE_AUTO_UPDATE" == "true" ]]; then
        (crontab -l 2>/dev/null; echo "0 4 * * 1 $INSTALL_DIR/update.sh >> $INSTALL_DIR/logs/cron.log 2>&1") | crontab -
    fi
    success "Cron jobs set up successfully."
}

build_and_deploy() {
    log "🏗️ Building and deploying containers..."
    cd "$INSTALL_DIR"
    $DOCKER_COMPOSE up -d --build --remove-orphans
    log "⏳ Waiting for services to become stable (max 3 minutes)..."
    local max_retries=12; local attempt=0
    while [[ $attempt -lt $max_retries ]]; do
        local n8n_health=$(docker inspect --format='{{.State.Health.Status}}' n8n-container 2>/dev/null)
        if [[ "$n8n_health" == "healthy" ]]; then
            success "🎉 All services are up and healthy!";
            return 0
        fi
        ((attempt++)); echo "   ... Check #${attempt}/${max_retries}: N8N Status ($n8n_health)"; sleep 15
    done
    error "N8N failed to reach a 'healthy' state after 3 minutes."
    docker compose logs n8n
    exit 1
}

show_final_summary() {
    clear
    success "🎉 N8N INSTALLATION SUCCESSFUL! 🎉"
    echo "--------------------------------------------------"
    if [[ "$LOCAL_MODE" == "true" ]]; then
        echo -e "🌐 Access your N8N instance at: ${WHITE}http://localhost:5678${NC}"
    else
        echo -e "🌐 Access your N8N instance at: ${WHITE}https://${DOMAIN}${NC}"
    fi
    echo -e "📁 Installation Directory: ${WHITE}${INSTALL_DIR}${NC}"
    echo -e "🔑 Encryption Key File (VERY IMPORTANT): ${WHITE}${INSTALL_DIR}/.env${NC}"
    echo "--------------------------------------------------"
    echo -e "📋 USEFUL COMMANDS:"
    echo -e " • View Logs:         ${WHITE}cd ${INSTALL_DIR} && docker compose logs -f n8n${NC}"
    echo -e " • Restart Services:  ${WHITE}cd ${INSTALL_DIR} && docker compose restart${NC}"
    echo -e " • Manual Update:     ${WHITE}bash ${INSTALL_DIR}/update.sh${NC}"
    echo -e " • Manual Backup:     ${WHITE}bash ${INSTALL_DIR}/backup.sh${NC}"
    echo -e " • Troubleshoot:      ${WHITE}bash ${INSTALL_DIR}/troubleshoot.sh${NC}"
    echo "--------------------------------------------------"
}

# =============================================================================
# >> MAIN EXECUTION
# =============================================================================
main() {
    parse_arguments "$@"
    show_banner
    check_root
    check_docker_compose
    
    get_restore_option
    if [[ -d "$INSTALL_DIR" && "$CLEAN_INSTALL" == "false" && "$RESTORE_MODE" == "false" ]]; then
        read -p "⚠️ Installation directory already exists. Delete and reinstall? (y/N): " -n 1 -r; echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then CLEAN_INSTALL=true; fi
    fi
    
    get_user_input
    
    cleanup_old_installation
    install_docker
    mkdir -p "$INSTALL_DIR/files"
    cd "$INSTALL_DIR"
    
    perform_restore
    
    setup_env_file
    create_dockerfile
    create_docker_compose
    create_caddyfile
    create_helper_scripts
    
    setup_cron_jobs
    build_and_deploy
    show_final_summary
}

main "$@"
