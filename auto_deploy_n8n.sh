#!/bin/bash

# =============================================================================
# 🚀 N8N AUTOMATIC INSTALLATION SCRIPT (FIXED)
# =============================================================================
set -e

# Colors
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'
PURPLE='\033[0;35m'; CYAN='\033[0;36m'; WHITE='\033[1;37m'; NC='\033[0m'

# Global vars
INSTALL_DIR="/home/n8n"
DOMAIN=""
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
RESTORE_SOURCE=""
RESTORE_FILE_PATH=""

# ---------------- Utils ----------------
show_banner() {
  clear
  echo -e "${CYAN}╔══════════════════════════════════════════════════════════════════════════════╗${NC}"
  echo -e "${CYAN}║${WHITE}                 🚀 N8N AUTOMATIC INSTALLATION SCRIPT 🚀                    ${CYAN}║${NC}"
  echo -e "${CYAN}╠══════════════════════════════════════════════════════════════════════════════╣${NC}"
  echo -e "${CYAN}║${WHITE} ✨ Installs N8N + FFmpeg + yt-dlp                                         ${CYAN}║${NC}"
  echo -e "${CYAN}║${WHITE} ✨ Telegram/GDrive Backups & Auto-Updates                                 ${CYAN}║${NC}"
  echo -e "${CYAN}║${WHITE} ✅ Optional restore from backup                                           ${CYAN}║${NC}"
  echo -e "${CYAN}║${WHITE} 🛡️  Caddy reverse proxy + SSL                                            ${CYAN}║${NC}"
  echo -e "${CYAN}╚══════════════════════════════════════════════════════════════════════════════╝${NC}"
  echo ""
}
log(){ echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] $1${NC}"; }
error(){ echo -e "${RED}[ERROR] $1${NC}" >&2; }
warning(){ echo -e "${YELLOW}[WARNING] $1${NC}"; }
info(){ echo -e "${BLUE}[INFO] $1${NC}"; }
success(){ echo -e "${GREEN}[SUCCESS] $1${NC}"; }

# ---------------- Args ----------------
show_help() {
  echo "Usage: $0 [OPTIONS]"
  echo ""
  echo "OPTIONS:"
  echo "  -h, --help          Show help"
  echo "  -d, --dir DIR       Install dir (default: /home/n8n)"
  echo "  -c, --clean         Clean previous install"
  echo "  -s, --skip-docker   Skip Docker install"
  echo "  -l, --local         Local mode (no domain/SSL)"
  echo ""
}
parse_arguments() {
  while [[ $# -gt 0 ]]; do
    case $1 in
      -h|--help) show_help; exit 0 ;;
      -d|--dir) INSTALL_DIR="$2"; shift 2 ;;
      -c|--clean) CLEAN_INSTALL=true; shift ;;
      -s|--skip-docker) SKIP_DOCKER=true; shift ;;
      -l|--local) LOCAL_MODE=true; shift ;;
      *) error "Invalid argument: $1"; show_help; exit 1 ;;
    esac
  done
}

# ---------------- System checks ----------------
check_root(){ if [[ $EUID -ne 0 ]]; then error "Run as root (sudo)."; exit 1; fi; }
check_os(){
  [[ -f /etc/os-release ]] || { error "Unknown OS"; exit 1; }
  . /etc/os-release
  if [[ "$ID" != "ubuntu" ]]; then
    warning "Script is for Ubuntu. Your OS: $ID"
    read -p "Continue anyway? (y/N): " -n 1 -r; echo
    [[ $REPLY =~ ^[Yy]$ ]] || exit 1
  fi
}
detect_environment(){
  if grep -q Microsoft /proc/version 2>/dev/null; then info "WSL detected."; export WSL_ENV=true; else export WSL_ENV=false; fi
}
check_docker_compose(){
  if docker compose version &>/dev/null 2>&1; then
    export DOCKER_COMPOSE="docker compose"; info "Using docker compose (v2)."
  elif command -v docker-compose &>/dev/null; then
    export DOCKER_COMPOSE="docker-compose"; warning "Using docker-compose v1."
  else
    export DOCKER_COMPOSE=""
  fi
}

# ---------------- Swap ----------------
setup_swap(){
  log "Setting up swap..."
  local ram_gb=$(free -g | awk '/^Mem:/{print $2}')
  local swap_size="4G"; [[ $ram_gb -le 2 ]] && swap_size="2G" || { [[ $ram_gb -le 4 ]] && swap_size="4G"; }
  if swapon --show | grep -q "/swapfile"; then info "Swap exists. Skip."; return 0; fi
  fallocate -l $swap_size /swapfile || dd if=/dev/zero of=/swapfile bs=1024 count=$((${swap_size%G} * 1024 * 1024))
  chmod 600 /swapfile; mkswap /swapfile; swapon /swapfile
  grep -q "/swapfile" /etc/fstab || echo "/swapfile none swap sw 0 0" >> /etc/fstab
  success "Swap $swap_size created."
}

# ---------------- Rclone / Restore (kept) ----------------
install_rclone(){ if command -v rclone &>/dev/null; then info "rclone already installed."; return 0; fi; apt-get update && apt-get install -y unzip; curl https://rclone.org/install.sh | sudo bash; success "rclone installed."; }
setup_rclone_config(){
  if rclone listremotes | grep -q "^${RCLONE_REMOTE_NAME}:"; then info "Remote exists. Skip."; return 0; fi
  echo; echo -e "${YELLOW}Follow rclone drive setup steps...${NC}"; read -p "Press Enter to start rclone config..."
  rclone config
  rclone listremotes | grep -q "^${RCLONE_REMOTE_NAME}:" || { error "rclone remote not configured."; exit 1; }
  success "rclone remote configured."
}
get_restore_option(){
  echo; read -p "Restore n8n data from backup? (y/N): " -n 1 -r; echo
  if [[ ! $REPLY =~ ^[Yy]$ ]]; then RESTORE_MODE=false; return 0; fi
  RESTORE_MODE=true; echo "Backup source:"; echo "  1) Local (.tar.gz)"; echo "  2) Google Drive (rclone)"; read -p "Choose [1]: " source_choice
  if [[ "$source_choice" == "2" ]]; then
    RESTORE_SOURCE="gdrive"; install_rclone; setup_rclone_config
    read -p "GDrive folder [n8n_backups]: " GDRIVE_FOLDER_INPUT; [[ -n "$GDRIVE_FOLDER_INPUT" ]] && GDRIVE_BACKUP_FOLDER="$GDRIVE_FOLDER_INPUT"
    log "Listing backups from Google Drive..."; mapfile -t backups < <(rclone lsf "$RCLONE_REMOTE_NAME:$GDRIVE_BACKUP_FOLDER" --include "*.tar.gz" | sort -r)
    [[ ${#backups[@]} -gt 0 ]] || { error "No backups found in GDrive '$GDRIVE_BACKUP_FOLDER'."; exit 1; }
    echo "Choose backup:"; for i in "${!backups[@]}"; do echo "  $((i+1)). ${backups[$i]}"; done
    read -p "Number: " file_idx; selected_backup="${backups[$((file_idx-1))]}"; [[ -n "$selected_backup" ]] || { error "Invalid selection."; exit 1; }
    log "Downloading '$selected_backup'..."; mkdir -p /tmp/n8n_restore; rclone copyto "$RCLONE_REMOTE_NAME:$GDRIVE_BACKUP_FOLDER/$selected_backup" "/tmp/n8n_restore/$selected_backup" --progress
    RESTORE_FILE_PATH="/tmp/n8n_restore/$selected_backup"; success "Downloaded."
  else
    RESTORE_SOURCE="local"
    while true; do read -p "Path to local backup (.tar.gz): " RESTORE_FILE_PATH; [[ -f "$RESTORE_FILE_PATH" ]] && break || error "File not found."; done
  fi
  log "Verifying backup..."; tar -tzf "$RESTORE_FILE_PATH" &>/dev/null || { error "Backup invalid/corrupt."; exit 1; }
  success "Backup file OK."
}
perform_restore(){
  [[ "$RESTORE_MODE" == "true" ]] || return 0
  log "Restoring from: $RESTORE_FILE_PATH"
  mkdir -p "$INSTALL_DIR/files"; rm -rf "$INSTALL_DIR/files/"* 2>/dev/null || true
  local temp_extract_dir="/tmp/n8n_restore_extract_$$"; mkdir -p "$temp_extract_dir"
  if tar -xzvf "$RESTORE_FILE_PATH" -C "$temp_extract_dir" > /tmp/extract_log.txt 2>&1; then
    local backup_content_dir=""
    if compgen -G "$temp_extract_dir/n8n_backup_*" > /dev/null; then
      backup_content_dir=$(find "$temp_extract_dir" -maxdepth 1 -type d -name "n8n_backup_*" | head -1)
    elif [[ -d "$temp_extract_dir/credentials" ]]; then
      backup_content_dir="$temp_extract_dir"
    fi
    [[ -n "$backup_content_dir" ]] || { error "Invalid backup structure."; cat /tmp/extract_log.txt; rm -rf "$temp_extract_dir"; exit 1; }
    if [[ -d "$backup_content_dir/credentials" ]]; then
      cp -a "$backup_content_dir/credentials/"* "$INSTALL_DIR/files/" 2>/dev/null || true
      [[ -f "$INSTALL_DIR/files/database.sqlite" ]] && chmod 644 "$INSTALL_DIR/files/database.sqlite" && chown 1000:1000 "$INSTALL_DIR/files/database.sqlite"
    fi
    if [[ -d "$backup_content_dir/config" ]]; then
      [[ -f "$INSTALL_DIR/docker-compose.yml" ]] && cp "$INSTALL_DIR/docker-compose.yml" "$INSTALL_DIR/docker-compose.yml.bak"
      [[ -f "$INSTALL_DIR/Caddyfile" ]] && cp "$INSTALL_DIR/Caddyfile" "$INSTALL_DIR/Caddyfile.bak"
      cp -a "$backup_content_dir/config/"* "$INSTALL_DIR/" 2>/dev/null || true
    fi
    rm -rf "$temp_extract_dir"; [[ "$RESTORE_SOURCE" == "gdrive" ]] && rm -rf "/tmp/n8n_restore"; chown -R 1000:1000 "$INSTALL_DIR/files/"
    success "Data restore completed."
  else
    error "Extract failed:"; cat /tmp/extract_log.txt; rm -rf "$temp_extract_dir"; exit 1
  fi
}

# ---------------- User inputs ----------------
get_installation_mode(){
  [[ "$LOCAL_MODE" == "true" ]] && return 0
  echo -e "${WHITE}Install mode:${NC}"; echo "  1) Production (domain + SSL)"; echo "  2) Local (no domain)"
  read -p "Install in Local Mode? (y/N): " -n 1 -r; echo; [[ $REPLY =~ ^[Yy]$ ]] && LOCAL_MODE=true || LOCAL_MODE=false
}
get_domain_input(){
  if [[ "$LOCAL_MODE" == "true" ]]; then DOMAIN="localhost"; info "Local Mode -> DOMAIN=localhost"; return 0; fi
  while true; do read -p "Domain (e.g. n8n.example.com): " DOMAIN
    if [[ -n "$DOMAIN" && "$DOMAIN" =~ ^[a-zA-Z0-9][a-zA-Z0-9.-]*[a-zA-Z0-9]$ ]]; then break; else error "Invalid domain."; fi
  done
  export DOMAIN; info "N8N Domain: $DOMAIN"
}
get_cleanup_option(){
  [[ "$CLEAN_INSTALL" == "true" ]] && return 0
  if [[ -d "$INSTALL_DIR" ]]; then warning "Old install exists at $INSTALL_DIR"
    read -p "Remove old installation first? (y/N): " -n 1 -r; echo; [[ $REPLY =~ ^[Yy]$ ]] && CLEAN_INSTALL=true
  fi
}
get_backup_config(){
  [[ "$LOCAL_MODE" == "true" ]] && { info "Skip backup setup in Local Mode."; return 0; }
  read -p "Enable Telegram backup? (Y/n): " -n 1 -r; echo
  if [[ ! $REPLY =~ ^[Nn]$ ]]; then
    ENABLE_TELEGRAM=true
    while true; do read -p "Telegram Bot Token: " TELEGRAM_BOT_TOKEN; [[ -n "$TELEGRAM_BOT_TOKEN" ]] && break; done
    while true; do read -p "Telegram Chat ID: " TELEGRAM_CHAT_ID; [[ -n "$TELEGRAM_CHAT_ID" ]] && break; done
  fi
  read -p "Enable Google Drive backup (rclone)? (Y/n): " -n 1 -r; echo
  if [[ ! $REPLY =~ ^[Nn]$ ]]; then
    ENABLE_GDRIVE_BACKUP=true; install_rclone; setup_rclone_config
    read -p "GDrive folder name [n8n_backups]: " GDRIVE_FOLDER_INPUT; [[ -n "$GDRIVE_FOLDER_INPUT" ]] && GDRIVE_BACKUP_FOLDER="$GDRIVE_FOLDER_INPUT"
  fi
}
get_auto_update_config(){
  [[ "$LOCAL_MODE" == "true" ]] && { info "Skip auto-update in Local Mode."; ENABLE_AUTO_UPDATE=false; return 0; }
  read -p "Enable Auto-Update scheduler? (Y/n): " -n 1 -r; echo
  [[ $REPLY =~ ^[Nn]$ ]] && ENABLE_AUTO_UPDATE=false || ENABLE_AUTO_UPDATE=true
}

# ---------------- DNS verify ----------------
verify_dns(){
  [[ "$LOCAL_MODE" == "true" ]] && { info "Skip DNS check in Local Mode."; return 0; }
  log "Checking DNS for ${DOMAIN}..."
  local server_ip=$(curl -s https://api.ipify.org || curl -s http://ipv4.icanhazip.com || echo "unknown")
  local domain_ip=$(dig +short "$DOMAIN" A | tail -n1)
  info "Server IP: ${server_ip} | ${DOMAIN} resolves to: ${domain_ip:-'not found'}"
  if [[ "$domain_ip" != "$server_ip" ]]; then
    warning "DNS not pointing to this server yet."
    read -p "Continue anyway? (y/N): " -n 1 -r; echo; [[ $REPLY =~ ^[Yy]$ ]] || exit 1
  else success "DNS OK."; fi
}

# ---------------- Cleanup old ----------------
cleanup_old_installation(){
  [[ "$CLEAN_INSTALL" == "true" ]] || return 0
  log "Removing old installation..."
  if [[ -d "$INSTALL_DIR" ]]; then cd "$INSTALL_DIR"; [[ -n "$DOCKER_COMPOSE" ]] && $DOCKER_COMPOSE down --volumes --remove-orphans 2>/dev/null || true; fi
  docker rmi n8n-custom-ffmpeg:latest 2>/dev/null || true
  rm -rf "$INSTALL_DIR"
  crontab -l 2>/dev/null | grep -v "/home/n8n" | crontab - 2>/dev/null || true
  success "Old installation removed."
}

# ---------------- Docker install ----------------
install_docker(){
  [[ "$SKIP_DOCKER" == "true" ]] && { info "Skip Docker install."; return 0; }
  if command -v docker &>/dev/null; then
    info "Docker installed."; docker info &>/dev/null || { systemctl start docker; systemctl enable docker; }
    if docker compose version &>/dev/null 2>&1; then export DOCKER_COMPOSE="docker compose"; else
      apt-get update; apt-get install -y docker-compose-plugin
      if docker compose version &>/dev/null 2>&1; then export DOCKER_COMPOSE="docker compose"; else
        if command -v docker-compose &>/dev/null; then export DOCKER_COMPOSE="docker-compose"; else export DOCKER_COMPOSE=""; fi
      fi
    fi
    return 0
  fi
  log "Installing Docker..."
  apt-get update
  apt-get install -y apt-transport-https ca-certificates curl gnupg lsb-release
  install -m 0755 -d /etc/apt/keyrings
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
  chmod a+r /etc/apt/keyrings/docker.asc
  echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | tee /etc/apt/sources.list.d/docker.list >/dev/null
  apt-get update
  apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
  systemctl start docker; systemctl enable docker
  usermod -aG docker $SUDO_USER 2>/dev/null || true
  export DOCKER_COMPOSE="docker compose"
  success "Docker installed."
}

# ---------------- Project layout ----------------
create_project_structure(){
  log "Creating project structure at $INSTALL_DIR..."
  mkdir -p "$INSTALL_DIR"; cd "$INSTALL_DIR"
  mkdir -p files/backup_full files/temp files/youtube_content_anylystic logs
  touch logs/backup.log logs/update.log logs/cron.log logs/health.log
  success "Directories created."
}

# ---------------- Dockerfile (cleaned; no config.js copy) ----------------
create_dockerfile(){
  log "Creating Dockerfile..."
  cat > "$INSTALL_DIR/Dockerfile" << 'EOF'
FROM n8nio/n8n:latest

USER root

# Basic deps
RUN for i in 1 2 3; do apk update && break || sleep 2; done && \
    apk add --no-cache ffmpeg python3 python3-dev py3-pip curl wget git build-base linux-headers ca-certificates && \
    rm -rf /var/cache/apk/* /tmp/* /var/tmp/*

# yt-dlp
RUN for i in 1 2 3; do pip3 install --break-system-packages --no-cache-dir --timeout=60 yt-dlp && break || (echo "Retry $i..." && sleep 5); done

# Perms
RUN mkdir -p /home/node/.n8n/nodes /data/youtube_content_anylystic && \
    chown -R 1000:1000 /home/node/.n8n /data && \
    chmod -R 755 /home/node/.n8n /data

USER node

HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
  CMD curl -f http://localhost:5678/healthz || exit 1

WORKDIR /data
EOF
  success "Dockerfile created."
}

# ---------------- docker-compose.yml (FIXED env + volumes) ----------------
create_docker_compose(){
  log "Creating docker-compose.yml..."
  if [[ "$LOCAL_MODE" == "true" ]]; then
cat > "$INSTALL_DIR/docker-compose.yml" << EOF
services:
  n8n:
    build:
      context: .
      pull: true
    container_name: n8n-container
    restart: unless-stopped
    ports:
      - "5678:5678"
    environment:
      - N8N_HOST=0.0.0.0
      - N8N_PORT=5678
      - N8N_PROTOCOL=http
      - N8N_EDITOR_BASE_URL=http://localhost:5678/
      - N8N_TRUSTED_PROXIES=loopback,uniquelocal,linklocal
      - NODE_ENV=production
      - WEBHOOK_URL=http://localhost:5678/
      - GENERIC_TIMEZONE=Asia/Jakarta
      - N8N_METRICS=true
      - N8N_LOG_LEVEL=info
      - N8N_LOG_OUTPUT=console
      - N8N_USER_FOLDER=/home/node/.n8n
      - N8N_ENCRYPTION_KEY=\${N8N_ENCRYPTION_KEY:-$(openssl rand -hex 32)}
      - DB_TYPE=sqlite
      - DB_SQLITE_DATABASE=/home/node/.n8n/database.sqlite
      - DB_SQLITE_POOL_SIZE=10
      - N8N_BASIC_AUTH_ACTIVE=false
      - N8N_RUNNERS_ENABLED=true
      - N8N_DISABLE_PRODUCTION_MAIN_PROCESS=false
      - EXECUTIONS_TIMEOUT=3600
      - EXECUTIONS_TIMEOUT_MAX=7200
      - N8N_EXECUTIONS_DATA_MAX_SIZE=500MB
      - N8N_BINARY_DATA_MODE=filesystem
      - N8N_BINARY_DATA_STORAGE=/files
      - N8N_DEFAULT_BINARY_DATA_FILESYSTEM_DIRECTORY=/files
      - N8N_DEFAULT_BINARY_DATA_TEMP_DIRECTORY=/files/temp
      - NODE_FUNCTION_ALLOW_BUILTIN=child_process,path,fs,util,os
      - N8N_SECURE_COOKIE=false
    volumes:
      - ./files:/home/node/.n8n
      - ./files:/files
      - ./files/youtube_content_anylystic:/data/youtube_content_anylystic
      - /var/run/docker.sock:/var/run/docker.sock:ro
    networks:
      - n8n_network

networks:
  n8n_network:
    driver: bridge
EOF
  else
cat > "$INSTALL_DIR/docker-compose.yml" << EOF
services:
  n8n:
    build:
      context: .
      pull: true
    container_name: n8n-container
    restart: unless-stopped
    ports:
      - "127.0.0.1:5678:5678"
    environment:
      - N8N_HOST=\${DOMAIN}
      - N8N_PORT=5678
      - N8N_PROTOCOL=https
      - N8N_EDITOR_BASE_URL=https://\${DOMAIN}/
      - N8N_TRUSTED_PROXIES=loopback,uniquelocal,linklocal
      - NODE_ENV=production
      - WEBHOOK_URL=https://\${DOMAIN}/
      - GENERIC_TIMEZONE=Asia/Jakarta
      - N8N_SECURE_COOKIE=true
      - N8N_METRICS=true
      - N8N_LOG_LEVEL=info
      - N8N_LOG_OUTPUT=console
      - N8N_USER_FOLDER=/home/node/.n8n
      - N8N_ENCRYPTION_KEY=\${N8N_ENCRYPTION_KEY:-$(openssl rand -hex 32)}
      - DB_TYPE=sqlite
      - DB_SQLITE_DATABASE=/home/node/.n8n/database.sqlite
      - DB_SQLITE_POOL_SIZE=10
      - N8N_BASIC_AUTH_ACTIVE=false
      - N8N_RUNNERS_ENABLED=true
      - N8N_DISABLE_PRODUCTION_MAIN_PROCESS=false
      - EXECUTIONS_TIMEOUT=3600
      - EXECUTIONS_TIMEOUT_MAX=7200
      - N8N_EXECUTIONS_DATA_MAX_SIZE=500MB
      - N8N_BINARY_DATA_MODE=filesystem
      - N8N_BINARY_DATA_STORAGE=/files
      - N8N_DEFAULT_BINARY_DATA_FILESYSTEM_DIRECTORY=/files
      - N8N_DEFAULT_BINARY_DATA_TEMP_DIRECTORY=/files/temp
      - NODE_FUNCTION_ALLOW_BUILTIN=child_process,path,fs,util,os
    volumes:
      - ./files:/home/node/.n8n
      - ./files:/files
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
  fi
  success "docker-compose.yml created."
}

# ---------------- Caddyfile (unchanged behavior) ----------------
create_caddyfile(){
  [[ "$LOCAL_MODE" == "true" ]] && { info "Skip Caddyfile in Local Mode."; return 0; }
  log "Creating Caddyfile..."
  cat > "$INSTALL_DIR/Caddyfile" << EOF
{
    email admin@${DOMAIN}
    acme_ca https://acme-v02.api.letsencrypt.org/directory
}

${DOMAIN} {
    reverse_proxy n8n:5678

    header {
        Strict-Transport-Security "max-age=31536000; includeSubDomains"
        X-Content-Type-Options "nosniff"
        X-Frame-Options "DENY"
        X-XSS-Protection "1; mode=block"
    }

    encode gzip

    handle_errors {
        @502 expression {http.error.status_code} == 502
        handle @502 {
            respond "N8N is starting up. Please wait and refresh." 502
        }
    }

    log {
        output file /var/log/caddy/n8n.log
        format json
    }
}
EOF
  success "Caddyfile created."
}

# ---------------- Backup scripts (kept) ----------------
create_backup_scripts(){
  log "Creating backup scripts..."
  cat > "$INSTALL_DIR/backup-workflows.sh" << 'EOF'
#!/bin/bash
set -e
BACKUP_DIR="/home/n8n/files/backup_full"
LOG_FILE="/home/n8n/logs/backup.log"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
BACKUP_NAME="n8n_backup_$TIMESTAMP"
TEMP_DIR="/tmp/$BACKUP_NAME"
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
log(){ echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] $1${NC}" | tee -a "$LOG_FILE"; }
error(){ echo -e "${RED}[ERROR] $1${NC}" | tee -a "$LOG_FILE"; }

mkdir -p "$BACKUP_DIR" "$(dirname "$LOG_FILE")" "$TEMP_DIR" "$TEMP_DIR/credentials" "$TEMP_DIR/config"
log "Starting n8n backup..."

# Database + key
if [[ -f "/home/n8n/files/database.sqlite" ]]; then
  cp "/home/n8n/files/database.sqlite" "$TEMP_DIR/credentials/" || { error "Copy DB failed"; exit 1; }
else
  DB_PATH=$(find /home/n8n/files -name "database.sqlite" -type f 2>/dev/null | head -1)
  [[ -n "$DB_PATH" ]] && cp "$DB_PATH" "$TEMP_DIR/credentials/" || error "database.sqlite not found."
fi
cp "/home/n8n/files/encryptionKey" "$TEMP_DIR/credentials/" 2>/dev/null || log "encryptionKey not found (first run is OK)."

# Configs
cp /home/n8n/docker-compose.yml "$TEMP_DIR/config/" 2>/dev/null || true
cp /home/n8n/Caddyfile "$TEMP_DIR/config/" 2>/dev/null || true
cp /home/n8n/telegram_config.txt "$TEMP_DIR/config/" 2>/dev/null || true
cp /home/n8n/gdrive_config.txt "$TEMP_DIR/config/" 2>/dev/null || true

# Metadata
cat > "$TEMP_DIR/backup_metadata.json" << EOL
{
  "backup_date": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "backup_name": "$BACKUP_NAME",
  "n8n_version": "$(docker exec n8n-container n8n --version 2>/dev/null || echo 'unknown')",
  "backup_type": "full",
  "files_included": $(find "$TEMP_DIR" -type f | wc -l)
}
EOL

# Archive
cd /tmp && tar -czf "$BACKUP_DIR/$BACKUP_NAME.tar.gz" "$BACKUP_NAME/" || { error "Create archive failed"; rm -rf "$TEMP_DIR"; exit 1; }

# Verify
tar -tzf "$BACKUP_DIR/$BACKUP_NAME.tar.gz" >/dev/null 2>&1 || { error "Archive corrupt"; rm -rf "$TEMP_DIR"; exit 1; }
BACKUP_SIZE=$(ls -lh "$BACKUP_DIR/$BACKUP_NAME.tar.gz" | awk '{print $5}')
log "Backup complete: $BACKUP_NAME.tar.gz ($BACKUP_SIZE)"
rm -rf "$TEMP_DIR"

# Rotate local (keep 30)
cd "$BACKUP_DIR"; ls -t n8n_backup_*.tar.gz 2>/dev/null | tail -n +31 | xargs -r rm -f

# Telegram
if [[ -f "/home/n8n/telegram_config.txt" ]]; then
  source "/home/n8n/telegram_config.txt"
  if [[ -n "$TELEGRAM_BOT_TOKEN" && -n "$TELEGRAM_CHAT_ID" ]]; then
    MESSAGE="🔄 *N8N Backup Completed*\n📅 $(date +'%Y-%m-%d %H:%M:%S')\n📦 $BACKUP_NAME.tar.gz\n💾 $BACKUP_SIZE\n✅ Success"
    curl -s -X POST "https://api.telegram.org/bot$TELEGRAM_BOT_TOKEN/sendMessage" \
      -d chat_id="$TELEGRAM_CHAT_ID" -d text="$MESSAGE" -d parse_mode="Markdown" >/dev/null || log "Telegram send failed."
  fi
fi

# Google Drive
if [[ -f "/home/n8n/gdrive_config.txt" ]]; then
  source "/home/n8n/gdrive_config.txt"
  if [[ -n "$RCLONE_REMOTE_NAME" && -n "$GDRIVE_BACKUP_FOLDER" ]]; then
    rclone copy "$BACKUP_DIR/$BACKUP_NAME.tar.gz" "$RCLONE_REMOTE_NAME:$GDRIVE_BACKUP_FOLDER" --progress || log "GDrive upload failed."
    rclone delete --min-age 30d "$RCLONE_REMOTE_NAME:$GDRIVE_BACKUP_FOLDER" || true
  fi
fi

log "Backup finished."
EOF
  chmod +x "$INSTALL_DIR/backup-workflows.sh"

  # Manual test helper (kept simple)
  cat > "$INSTALL_DIR/backup-manual.sh" << 'EOF'
#!/bin/bash
echo "Running manual backup..."
/home/n8n/backup-workflows.sh
EOF
  chmod +x "$INSTALL_DIR/backup-manual.sh"
  success "Backup scripts created."
}

# ---------------- Cron / Auto update (kept same behavior) ----------------
setup_cron_jobs(){
  log "Configuring cron..."
  crontab -l 2>/dev/null | grep -v "/home/n8n/backup-workflows.sh" | crontab - 2>/dev/null || true
  (crontab -l 2>/dev/null; echo "0 2 * * * /home/n8n/backup-workflows.sh >> /home/n8n/logs/cron.log 2>&1") | crontab -
  if [[ "$ENABLE_AUTO_UPDATE" == "true" ]]; then
    (crontab -l 2>/dev/null; echo "0 */12 * * * /home/n8n/update.sh >> /home/n8n/logs/update.log 2>&1") | crontab -
  fi
  success "Cron configured."
}

# ---------------- Run / Bring up ----------------
bring_up_stack(){
  cd "$INSTALL_DIR"
  export DOMAIN
  $DOCKER_COMPOSE build --pull
  $DOCKER_COMPOSE up -d
  success "Stack is up."
  if [[ "$LOCAL_MODE" == "true" ]]; then
    echo -e "${GREEN}Open: http://localhost:5678/${NC}"
  else
    echo -e "${GREEN}Open: https://${DOMAIN}/${NC}"
  fi
}

# ---------------- Main ----------------
main(){
  show_banner
  parse_arguments "$@"
  check_root; check_os; detect_environment; check_docker_compose
  get_installation_mode; get_domain_input; get_cleanup_option
  get_backup_config; get_auto_update_config
  [[ "$LOCAL_MODE" == "true" ]] || verify_dns
  cleanup_old_installation
  install_docker
  setup_swap
  create_project_structure
  create_dockerfile
  create_docker_compose
  create_caddyfile
  create_backup_scripts
  if [[ "$ENABLE_TELEGRAM" == "true" ]]; then
    cat > "$INSTALL_DIR/telegram_config.txt" <<EOF
TELEGRAM_BOT_TOKEN=${TELEGRAM_BOT_TOKEN}
TELEGRAM_CHAT_ID=${TELEGRAM_CHAT_ID}
EOF
  fi
  if [[ "$ENABLE_GDRIVE_BACKUP" == "true" ]]; then
    cat > "$INSTALL_DIR/gdrive_config.txt" <<EOF
RCLONE_REMOTE_NAME=${RCLONE_REMOTE_NAME}
GDRIVE_BACKUP_FOLDER=${GDRIVE_BACKUP_FOLDER}
EOF
  fi
  get_restore_option
  perform_restore
  setup_cron_jobs
  bring_up_stack
  success "Installation complete."
}

main "$@"
