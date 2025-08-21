#!/bin/bash

# =============================================================================
# 🚀 AUTOMATED N8N INSTALLATION SCRIPT 2025
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
    echo -e "${YELLOW}║${WHITE}             ⚙️ PANDUAN KONFIGURASI RCLONE + GOOGLE DRIVE ⚙️              ${YELLOW}║${NC}"
    echo -e "${YELLOW}╚══════════════════════════════════════════════════════════════════════════════╝${NC}"
    echo "Anda akan masuk ke mode konfigurasi rclone. Ikuti panduan ini dengan TEPAT."
    echo ""
    echo -e "   Skrip akan menjalankan ${CYAN}rclone config${NC}. Ikuti dialog interaktifnya:"
    echo ""
    echo -e "   1. Saat ditanya ${WHITE}n/s/q> ${NC}, ketik ${GREEN}n${NC} lalu [Enter] (untuk New remote)."
    echo ""
    echo -e "   2. Saat ditanya ${WHITE}name> ${NC}, ketik nama remote ini:"
    echo -e "      ${RED}👉 ${RCLONE_REMOTE_NAME} ${NC}"
    echo -e "      (PENTING: Nama harus sama persis, lalu tekan [Enter])"
    echo ""
    echo -e "   3. Anda akan melihat daftar cloud storage. Cari ${WHITE}Google Drive${NC}."
    echo -e "      Ketik nomor yang sesuai (misal: ${GREEN}17${NC}) atau ketik ${GREEN}drive${NC}, lalu [Enter]."
    echo ""
    echo -e "   4. Untuk ${WHITE}client_id> ${NC} dan ${WHITE}client_secret> ${NC}, biarkan kosong. Langsung [Enter] 2x."
    echo ""
    echo -e "   5. Untuk ${WHITE}scope> ${NC}, pilih akses penuh. Ketik ${GREEN}1${NC} lalu [Enter]."
    echo ""
    echo -e "   6. Untuk ${WHITE}root_folder_id> ${NC} dan ${WHITE}service_account_file> ${NC}, biarkan kosong. Langsung [Enter] 2x."
    echo ""
    echo -e "   7. Saat ditanya ${WHITE}Edit advanced config? (y/n)> ${NC}, ketik ${GREEN}n${NC} lalu [Enter]."
    echo ""
    echo -e "   8. Saat ditanya ${WHITE}Use auto config? (y/n)> ${NC}, ketik ${RED}n${NC} lalu [Enter]."
    echo -e "      ${YELLOW}(Ini langkah krusial jika Anda terhubung via SSH).${NC}"
    echo ""
    echo -e "   9. Rclone akan menampilkan sebuah link otorisasi. ${CYAN}Salin (copy) link tersebut${NC}."
    echo -e "      Buka link di browser komputer Anda, login ke akun Google, dan berikan izin."
    echo ""
    echo -e "  10. Setelah memberi izin, Google akan memberikan kode verifikasi di browser."
    echo -e "      ${CYAN}Salin kode tersebut dan tempel (paste) kembali ke terminal${NC}, lalu [Enter]."
    echo ""
    echo -e "  11. Saat ditanya ${WHITE}Configure this as a team drive? (y/n)> ${NC}, ketik ${GREEN}n${NC} lalu [Enter]."
    echo ""
    echo -e "  12. Konfirmasi pengaturan. Ketik ${GREEN}y${NC} lalu [Enter]."
    echo ""
    echo -e "  13. Anda kembali ke menu utama rclone. Ketik ${GREEN}q${NC} lalu [Enter] untuk keluar."
    echo ""
    read -p "Tekan [Enter] jika Anda sudah siap untuk memulai 'rclone config'..."

    rclone config

    if ! rclone listremotes | grep -q "^${RCLONE_REMOTE_NAME}:"; then
        error "Konfigurasi remote rclone '${RCLONE_REMOTE_NAME}' gagal. Silakan coba lagi."
        exit 1
    fi
    success "Remote rclone '${RCLONE_REMOTE_NAME}' berhasil dikonfigurasi!"
}

get_restore_option() {
    # (Fungsi ini tidak diubah secara signifikan, tetap seperti sebelumnya)
    echo ""
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${WHITE}                        🔄 OPSI RESTORE DATA                                ${CYAN}║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    read -p "🔄 Apakah Anda ingin me-restore data dari backup yang sudah ada? (y/N): " -n 1 -r; echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        RESTORE_MODE=false
        return 0
    fi
    RESTORE_MODE=true
    echo "Pilih sumber restore:"
    echo -e "  ${GREEN}1. Dari file backup lokal (.tar.gz)${NC}"
    echo -e "  ${GREEN}2. Dari Google Drive (membutuhkan konfigurasi rclone)${NC}"
    read -p "Pilihan Anda [1]: " source_choice
    if [[ "$source_choice" == "2" ]]; then
        RESTORE_SOURCE="gdrive"
        install_rclone
        setup_rclone_config
        read -p "📝 Masukkan nama folder di Google Drive [${GDRIVE_BACKUP_FOLDER}]: " GDRIVE_FOLDER_INPUT
        if [[ -n "$GDRIVE_FOLDER_INPUT" ]]; then GDRIVE_BACKUP_FOLDER="$GDRIVE_FOLDER_INPUT"; fi
        log "🔍 Mengambil daftar backup dari Google Drive..."
        mapfile -t backups < <(rclone lsf "$RCLONE_REMOTE_NAME:$GDRIVE_BACKUP_FOLDER" --include "*.tar.gz" | sort -r)
        if [ ${#backups[@]} -eq 0 ]; then
            error "Tidak ada file backup di folder '$GDRIVE_BACKUP_FOLDER'."
            exit 1
        fi
        echo "Pilih file backup untuk di-restore:"
        for i in "${!backups[@]}"; do
            echo "  $((i+1)). ${backups[$i]}"
        done
        read -p "Masukkan nomor file: " file_idx
        selected_backup="${backups[$((file_idx-1))]}"
        if [[ -z "$selected_backup" ]]; then
            error "Pilihan tidak valid."
            exit 1
        fi
        log "📥 Mengunduh file backup '$selected_backup'..."
        mkdir -p /tmp/n8n_restore
        rclone copyto "$RCLONE_REMOTE_NAME:$GDRIVE_BACKUP_FOLDER/$selected_backup" "/tmp/n8n_restore/$selected_backup" --progress
        RESTORE_FILE_PATH="/tmp/n8n_restore/$selected_backup"
        success "File backup berhasil diunduh."
    else
        RESTORE_SOURCE="local"
        while true; do
            read -p "📁 Masukkan path lengkap ke file backup (.tar.gz): " RESTORE_FILE_PATH
            if [[ -f "$RESTORE_FILE_PATH" ]]; then break; else error "File tidak ditemukan."; fi
        done
    fi
    log "🔍 Memeriksa integritas file backup..."
    if ! tar -tzf "$RESTORE_FILE_PATH" &>/dev/null; then
        error "File backup korup atau formatnya salah."
        exit 1
    fi
    success "File backup valid."
}

perform_restore() {
    # (Fungsi ini tidak diubah secara signifikan, tetap seperti sebelumnya)
    if [[ "$RESTORE_MODE" != "true" ]]; then return 0; fi
    log "🔄 Memulai proses restore dari: $RESTORE_FILE_PATH"
    mkdir -p "$INSTALL_DIR/files"
    log "🧹 Membersihkan data lama..."
    rm -rf "$INSTALL_DIR/files/"* 2>/dev/null || true
    log "📦 Mengekstrak file backup..."
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
            log "Menemukan konten backup di: $backup_content_dir"
            if [[ -d "$backup_content_dir/credentials" ]]; then
                log "Me-restore database dan key..."
                cp -a "$backup_content_dir/credentials/"* "$INSTALL_DIR/files/" 2>/dev/null || true
            fi
            if [[ -f "$backup_content_dir/config/docker-compose.yml" ]]; then
                log "🔑 Mengekstrak encryption key dari backup..."
                local old_key=$(grep 'N8N_ENCRYPTION_KEY' "$backup_content_dir/config/docker-compose.yml" | head -n 1 | cut -d '=' -f2-)
                if [[ -n "$old_key" ]]; then
                    N8N_ENCRYPTION_KEY="$old_key"
                    info "Berhasil mengekstrak encryption key lama."
                else
                    warning "Tidak dapat mengekstrak encryption key. Ini bisa menyebabkan masalah pada kredensial lama."
                fi
            fi
        else
            error "Struktur file backup tidak valid."
            exit 1
        fi
        rm -rf "$temp_extract_dir"
        if [[ "$RESTORE_SOURCE" == "gdrive" ]]; then rm -rf "/tmp/n8n_restore"; fi
        chown -R 1000:1000 "$INSTALL_DIR/files/"
        success "✅ Data berhasil di-restore!"
    else
        error "Gagal mengekstrak file backup."
        rm -rf "$temp_extract_dir"
        exit 1
    fi
}

# =============================================================================
# USER INPUT FUNCTIONS
# =============================================================================

get_domain_input() {
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${WHITE}                           🌐 KONFIGURASI DOMAIN                                 ${CYAN}║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════════════════════╝${NC}"
    echo "Instalasi ini membutuhkan sebuah domain yang sudah diarahkan (A Record) ke IP server ini."
    while true; do
        read -p "🌐 Masukkan domain utama untuk N8N (contoh: n8n.domain.com): " DOMAIN
        if [[ -n "$DOMAIN" && "$DOMAIN" =~ ^[a-zA-Z0-9][a-zA-Z0-9.-]*[a-zA-Z0-9]$ ]]; then
            break
        else
            error "Format domain tidak valid. Silakan coba lagi."
        fi
    done
    info "Domain N8N akan diinstal di: ${DOMAIN}"
}

get_cleanup_option() {
    if [[ "$CLEAN_INSTALL" == "true" ]]; then return 0; fi
    if [[ -d "$INSTALL_DIR" ]]; then
        warning "Direktori instalasi N8N lama terdeteksi di: $INSTALL_DIR"
        read -p "🗑️  Apakah Anda ingin menghapus instalasi lama dan memulai dari awal? (y/N): " -n 1 -r; echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            CLEAN_INSTALL=true
        fi
    fi
}

get_backup_config() {
    echo ""
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${WHITE}                      💾 KONFIGURASI BACKUP OTOMATIS                          ${CYAN}║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════════════════════╝${NC}"
    # Telegram Backup
    read -p "📱 Apakah Anda ingin mengatur notifikasi backup via Telegram? (Y/n): " -n 1 -r; echo
    if [[ ! $REPLY =~ ^[Nn]$ ]]; then
        ENABLE_TELEGRAM=true
        info "Untuk mendapatkan Token dan Chat ID, ikuti panduan di dokumentasi BotFather dan UserInfoBot di Telegram."
        while true; do read -p "🤖 Masukkan Telegram Bot Token: " TELEGRAM_BOT_TOKEN; if [[ -n "$TELEGRAM_BOT_TOKEN" ]]; then break; fi; done
        while true; do read -p "🆔 Masukkan Telegram Chat ID: " TELEGRAM_CHAT_ID; if [[ -n "$TELEGRAM_CHAT_ID" ]]; then break; fi; done
        success "Backup Telegram dikonfigurasi."
    fi
    # Google Drive Backup
    read -p "☁️ Apakah Anda ingin mengatur backup ke Google Drive? (Y/n): " -n 1 -r; echo
    if [[ ! $REPLY =~ ^[Nn]$ ]]; then
        ENABLE_GDRIVE_BACKUP=true
        install_rclone
        setup_rclone_config
        read -p "📝 Masukkan nama folder di Google Drive untuk menyimpan backup [${GDRIVE_BACKUP_FOLDER}]: " GDRIVE_FOLDER_INPUT
        if [[ -n "$GDRIVE_FOLDER_INPUT" ]]; then GDRIVE_BACKUP_FOLDER="$GDRIVE_FOLDER_INPUT"; fi
        success "Backup Google Drive dikonfigurasi."
    fi
}

get_auto_update_config() {
    echo ""
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${WHITE}                        🔄 AUTO-UPDATE N8N                                  ${CYAN}║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════════════════════╝${NC}"
    echo "Fitur ini akan otomatis memperbarui N8N, membuat backup sebelum update, dan memberi notifikasi."
    read -p "🔄 Apakah Anda ingin mengaktifkan Auto-Update (setiap 12 jam)? (Y/n): " -n 1 -r; echo
    if [[ ! $REPLY =~ ^[Nn]$ ]]; then
        ENABLE_AUTO_UPDATE=true
        success "Auto-Update diaktifkan."
    else
        ENABLE_AUTO_UPDATE=false
    fi
}

# =============================================================================
# DNS VERIFICATION
# =============================================================================

verify_dns() {
    log "🔍 Memverifikasi DNS untuk domain ${DOMAIN}..."
    local server_ip=$(curl -s https://api.ipify.org || curl -s http://ipv4.icanhazip.com || echo "unknown")
    info "IP Server Anda: ${server_ip}"
    local domain_ip=$(dig +short "$DOMAIN" A | tail -n1)
    info "IP domain ${DOMAIN} saat ini: ${domain_ip:-"tidak ditemukan"}"
    if [[ "$domain_ip" != "$server_ip" ]]; then
        warning "DNS domain belum mengarah ke IP server ini!"
        echo -e "${YELLOW}Pastikan Anda telah membuat A Record di DNS manager Anda: ${DOMAIN} -> ${server_ip}${NC}"
        read -p "🤔 Lanjutkan instalasi? (SSL mungkin akan gagal) (y/N): " -n 1 -r; echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    else
        success "Verifikasi DNS berhasil."
    fi
}

# =============================================================================
# INSTALLATION & SETUP
# =============================================================================

cleanup_old_installation() {
    if [[ "$CLEAN_INSTALL" != "true" ]]; then return 0; fi
    log "🗑️ Menghapus instalasi lama..."
    if [[ -d "$INSTALL_DIR" ]]; then
        cd "$INSTALL_DIR"
        if [[ -n "$DOCKER_COMPOSE" ]]; then
            $DOCKER_COMPOSE down --volumes --remove-orphans 2>/dev/null || true
        fi
    fi
    rm -rf "$INSTALL_DIR"
    crontab -l 2>/dev/null | grep -v "$INSTALL_DIR" | crontab - 2>/dev/null || true
    success "Instalasi lama berhasil dihapus."
}

install_docker() {
    if [[ "$SKIP_DOCKER" == "true" ]]; then info "Melewatkan instalasi Docker."; return 0; fi
    if command -v docker &> /dev/null; then
        info "Docker sudah terinstal."
        if ! docker info &> /dev/null; then systemctl start docker && systemctl enable docker; fi
        if ! docker compose version &> /dev/null; then
            log "Menginstal Docker Compose Plugin (v2)..."
            apt-get update && apt-get install -y docker-compose-plugin
            export DOCKER_COMPOSE="docker compose"
        fi
        return 0
    fi
    log "📦 Menginstal Docker Engine..."
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
    success "Docker berhasil diinstal."
}

create_project_structure() {
    log "📁 Membuat struktur direktori proyek..."
    mkdir -p "$INSTALL_DIR"/{files/backup_full,files/temp,files/youtube_content_anylystic,logs}
    touch "$INSTALL_DIR"/logs/{backup.log,update.log,cron.log,health.log}
    success "Struktur direktori dibuat di $INSTALL_DIR"
}

setup_env_file() {
    log "🔐 Menyiapkan file environment (.env)..."
    if [[ -z "$N8N_ENCRYPTION_KEY" ]]; then
        if [[ -f "$INSTALL_DIR/.env" ]]; then
            info "Menemukan file .env, memuat encryption key yang ada."
            set -a; source "$INSTALL_DIR/.env"; set +a
        else
            info "Membuat encryption key baru."
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
    success ".env file berhasil dibuat dan diamankan."
}

create_dockerfile() {
    log "🐳 Membuat Dockerfile untuk N8N (dengan FFmpeg & yt-dlp)..."
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
    success "Dockerfile berhasil dibuat."
}

create_docker_compose() {
    log "🐳 Membuat file docker-compose.yml..."
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
    success "docker-compose.yml berhasil dibuat."
}

create_caddyfile() {
    log "🌐 Membuat file konfigurasi Caddy (Caddyfile)..."
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
    success "Caddyfile berhasil dibuat."
}

# =============================================================================
# HELPER SCRIPTS (Backup, Update, etc.)
# =============================================================================

create_backup_scripts() {
    log "💾 Membuat skrip backup..."
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
log "🔄 Memulai backup N8N..."
cp "/home/n8n/files/database.sqlite" "$TEMP_DIR/credentials/"
cp "/home/n8n/.env" "$TEMP_DIR/config/"
log "📦 Mengkompres file backup..."
cd /tmp && tar -czf "$BACKUP_DIR/$BACKUP_NAME.tar.gz" "$BACKUP_NAME/"
BACKUP_SIZE=$(ls -lh "$BACKUP_DIR/$BACKUP_NAME.tar.gz" | awk '{print $5}')
log "✅ Backup selesai: $BACKUP_NAME.tar.gz ($BACKUP_SIZE)"
rm -rf "$TEMP_DIR"
log "🧹 Membersihkan backup lokal lama (menyisakan 30 terakhir)..."
ls -t "$BACKUP_DIR"/n8n_backup_*.tar.gz 2>/dev/null | tail -n +31 | xargs -r rm -f
if [[ -f "/home/n8n/telegram_config.txt" ]]; then
    source "/home/n8n/telegram_config.txt"
    MESSAGE="🔄 *N8N Backup Selesai*\nFile: \`$BACKUP_NAME.tar.gz\`\nUkuran: $BACKUP_SIZE"
    curl -s -X POST "https://api.telegram.org/bot$TELEGRAM_BOT_TOKEN/sendMessage" -d chat_id="$TELEGRAM_CHAT_ID" -d text="$MESSAGE" -d parse_mode="Markdown" > /dev/null
fi
if [[ -f "/home/n8n/gdrive_config.txt" ]]; then
    source "/home/n8n/gdrive_config.txt"
    log "☁️ Mengunggah ke Google Drive..."
    rclone copy "$BACKUP_DIR/$BACKUP_NAME.tar.gz" "$RCLONE_REMOTE_NAME:$GDRIVE_BACKUP_FOLDER" --progress
    log "🧹 Membersihkan backup Google Drive lama (lebih dari 30 hari)..."
    rclone delete --min-age 30d "$RCLONE_REMOTE_NAME:$GDRIVE_BACKUP_FOLDER"
fi
log "🎉 Proses backup selesai."
EOF
    chmod +x "$INSTALL_DIR/backup-workflows.sh"
    # Manual backup script
    cat > "$INSTALL_DIR/backup-manual.sh" << 'EOF'
#!/bin/bash
echo "Menjalankan backup manual..."
/home/n8n/backup-workflows.sh
echo "Selesai. Cek log di /home/n8n/logs/backup.log dan file di /home/n8n/files/backup_full"
EOF
    chmod +x "$INSTALL_DIR/backup-manual.sh"
    success "Skrip backup berhasil dibuat."
}

create_update_script() {
    log "🔄 Membuat skrip auto-update..."
    cat > "$INSTALL_DIR/update-n8n.sh" << 'EOF'
#!/bin/bash
set -e
LOG_FILE="/home/n8n/logs/update.log"
log() { echo "[$(date)] $1" | tee -a "$LOG_FILE"; }
send_telegram() { if [[ -f "/home/n8n/telegram_config.txt" ]]; then source "/home/n8n/telegram_config.txt"; curl -s -X POST "https://api.telegram.org/bot$TELEGRAM_BOT_TOKEN/sendMessage" -d chat_id="$TELEGRAM_CHAT_ID" -d text="$1" -d parse_mode="Markdown" > /dev/null; fi; }
cd /home/n8n
log "🔄 Memulai auto-update N8N..."
log "💾 Membuat backup sebelum update..."
./backup-workflows.sh
log "📦 Menarik image Docker terbaru..."
docker compose pull
log "🚀 Memulai ulang container..."
docker compose up -d --remove-orphans
log "🧹 Membersihkan image lama..."
docker image prune -f
log "🎉 Proses update selesai."
send_telegram "✅ *N8N Auto-Update Berhasil*\nN8N telah diperbarui ke versi terbaru."
EOF
    chmod +x "$INSTALL_DIR/update-n8n.sh"
    success "Skrip auto-update berhasil dibuat."
}

create_health_monitor() {
    log "🏥 Membuat skrip health monitor..."
    cat > "$INSTALL_DIR/health-monitor.sh" << 'EOF'
#!/bin/bash
LOG_FILE="/home/n8n/logs/health.log"
TIMESTAMP=$(date +"%Y-%m-%d %H:%M:%S")
N8N_HEALTH=$(curl -s -o /dev/null -w "%{http_code}" http://127.0.0.1:5678/healthz || echo "000")
N8N_STATUS=$(docker inspect -f '{{.State.Status}}' n8n-container 2>/dev/null || echo "not_found")
echo "[$TIMESTAMP] Health: $N8N_HEALTH, Container: $N8N_STATUS" >> "$LOG_FILE"
if [[ "$N8N_HEALTH" != "200" ]] || [[ "$N8N_STATUS" != "running" ]]; then
    echo "[$TIMESTAMP] N8N tidak sehat! Mencoba restart..." >> "$LOG_FILE"
    cd /home/n8n && docker compose restart n8n
    if [[ -f "/home/n8n/telegram_config.txt" ]]; then
        source "/home/n8n/telegram_config.txt"
        MESSAGE="⚠️ *Peringatan Kesehatan N8N*\nStatus: Tidak Sehat (Code: $N8N_HEALTH, Status: $N8N_STATUS)\nMencoba restart otomatis."
        curl -s -X POST "https://api.telegram.org/bot$TELEGRAM_BOT_TOKEN/sendMessage" -d chat_id="$TELEGRAM_CHAT_ID" -d text="$MESSAGE" -d parse_mode="Markdown" > /dev/null
    fi
fi
EOF
    chmod +x "$INSTALL_DIR/health-monitor.sh"
    success "Skrip health monitor dibuat."
}

create_troubleshooting_script() {
    log "🔧 Membuat skrip troubleshooting..."
    cat > "$INSTALL_DIR/troubleshoot.sh" << 'EOF'
#!/bin/bash
CYAN='\033[0;36m'; WHITE='\033[1;37m'; NC='\033[0m'; BLUE='\033[0;34m';
echo -e "${CYAN}╔══════════════════ 🔧 N8N TROUBLESHOOTING 🔧 ══════════════════╗${NC}\n"
cd /home/n8n
DOMAIN=$(grep -E "^[a-zA-Z0-9.-]+\s*{" Caddyfile | head -1 | awk '{print $1}')
echo -e "${BLUE}📍 Info Sistem & Docker:${NC}"
echo " • OS: $(lsb_release -ds)"
echo " • Docker: $(docker --version)"
echo " • Docker Compose: $(docker compose version)"
echo -e "\n${BLUE}📍 Status Container:${NC}"; docker compose ps
echo -e "\n${BLUE}📍 Info Instalasi:${NC}"
echo " • Mode: Produksi (SSL)"
echo " • Domain: $DOMAIN"
echo -e "\n${BLUE}📍 Status SSL & DNS:${NC}"
echo " • DNS Resolution: $(dig +short $DOMAIN A | tail -1)"
echo " • SSL Test: $(timeout 5 curl -Is https://$DOMAIN 2>/dev/null | head -1 || echo 'Gagal terhubung')"
echo -e "\n${BLUE}📍 10 Error Log Terakhir (N8N):${NC}"
docker compose logs n8n 2>&1 | grep -iE "(error|warn)" | tail -10 || echo " Tidak ada error/warning ditemukan."
echo -e "\n${CYAN}╚════════════════════════════════════════════════════════════════╝${NC}"
EOF
    chmod +x "$INSTALL_DIR/troubleshoot.sh"
    success "Skrip troubleshooting dibuat."
}

# =============================================================================
# FINALIZATION
# =============================================================================

setup_backup_configs() {
    if [[ "$ENABLE_TELEGRAM" == "true" ]]; then
        log "📱 Menyimpan konfigurasi Telegram..."
        echo "TELEGRAM_BOT_TOKEN=\"$TELEGRAM_BOT_TOKEN\"" > "$INSTALL_DIR/telegram_config.txt"
        echo "TELEGRAM_CHAT_ID=\"$TELEGRAM_CHAT_ID\"" >> "$INSTALL_DIR/telegram_config.txt"
        chmod 600 "$INSTALL_DIR/telegram_config.txt"
    fi
    if [[ "$ENABLE_GDRIVE_BACKUP" == "true" ]]; then
        log "☁️ Menyimpan konfigurasi Google Drive..."
        echo "RCLONE_REMOTE_NAME=\"$RCLONE_REMOTE_NAME\"" > "$INSTALL_DIR/gdrive_config.txt"
        echo "GDRIVE_BACKUP_FOLDER=\"$GDRIVE_BACKUP_FOLDER\"" >> "$INSTALL_DIR/gdrive_config.txt"
        chmod 600 "$INSTALL_DIR/gdrive_config.txt"
    fi
}

setup_cron_jobs() {
    log "⏰ Mengatur cron jobs..."
    (crontab -l 2>/dev/null | grep -v "$INSTALL_DIR") | crontab -
    (crontab -l 2>/dev/null; echo "0 2 * * * $INSTALL_DIR/backup-workflows.sh >> $INSTALL_DIR/logs/cron.log 2>&1") | crontab -
    if [[ "$ENABLE_AUTO_UPDATE" == "true" ]]; then
        (crontab -l 2>/dev/null; echo "0 */12 * * * $INSTALL_DIR/update-n8n.sh >> $INSTALL_DIR/logs/cron.log 2>&1") | crontab -
    fi
    (crontab -l 2>/dev/null; echo "*/5 * * * * $INSTALL_DIR/health-monitor.sh >> $INSTALL_DIR/logs/cron.log 2>&1") | crontab -
    log "Cron jobs yang diatur:"
    crontab -l | grep "$INSTALL_DIR"
    success "Cron jobs berhasil diatur."
}

build_and_deploy() {
    log "🏗️ Membangun dan menjalankan container..."
    cd "$INSTALL_DIR"
    log "🔐 Mengatur izin untuk direktori data..."
    chown -R 1000:1000 "$INSTALL_DIR/files/"
    log "📦 Membangun image Docker (ini mungkin butuh beberapa menit)..."
    $DOCKER_COMPOSE build --no-cache
    log "🚀 Menjalankan semua layanan..."
    $DOCKER_COMPOSE up -d
    log "⏳ Menunggu layanan stabil dan sehat (maks 3 menit)..."
    sleep 15 # Give some initial time for containers to start
    local max_retries=12; local attempt=0
    while [[ $attempt -lt $max_retries ]]; do
        n8n_health=$(docker inspect --format='{{.State.Health.Status}}' n8n-container 2>/dev/null)
        caddy_status=$(docker inspect --format='{{.State.Status}}' caddy-proxy 2>/dev/null)
        if [[ "$n8n_health" == "healthy" && "$caddy_status" == "running" ]]; then
            success "🎉 Semua layanan berjalan dan sehat!"
            return 0
        fi
        ((attempt++)); echo "   ... Cek ke-${attempt}/${max_retries}: N8N ($n8n_health), Caddy ($caddy_status)"; sleep 15
    done
    error "Satu atau lebih layanan gagal dimulai dengan benar setelah 3 menit."
    $DOCKER_COMPOSE ps
    $DOCKER_COMPOSE logs --tail=50
    exit 1
}

check_ssl() {
    log "🔒 Memverifikasi penerbitan sertifikat SSL (maks 2 menit)..."
    local max_retries=12; local attempt=0;
    while [[ $attempt -lt $max_retries ]]; do
        if $DOCKER_COMPOSE logs caddy 2>&1 | grep -q "certificate obtained successfully"; then
            success "✅ Sertifikat SSL untuk ${DOMAIN} berhasil diterbitkan."
            return 0
        fi
        if $DOCKER_COMPOSE logs caddy 2>&1 | grep -q "urn:ietf:params:acme:error:rateLimited"; then
            error "🚨 TERDETEKSI RATE LIMIT SSL!"
            warning "Anda telah terlalu sering meminta sertifikat untuk domain ini."
            warning "Coba lagi dalam beberapa jam atau seminggu. Untuk sementara, N8N tidak akan bisa diakses."
            return 1
        fi
        ((attempt++)); echo "   ... Menunggu status SSL (percobaan ${attempt}/${max_retries})"; sleep 10
    done
    warning "Tidak dapat mengonfirmasi status SSL. Silakan cek log Caddy manual: docker compose -f ${INSTALL_DIR}/docker-compose.yml logs caddy"
}

show_final_summary() {
    clear
    echo -e "${GREEN}╔══════════════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║${WHITE}                 🎉 INSTALASI N8N BERHASIL DILAKUKAN! 🎉                 ${GREEN}║${NC}"
    echo -e "${GREEN}╚══════════════════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${CYAN}🌐 AKSES N8N ANDA DI:${NC}"
    echo -e "   ${WHITE}https://${DOMAIN}${NC}"
    echo ""
    echo -e "${CYAN}📁 INFORMASI SISTEM:${NC}"
    echo -e " • Direktori Instalasi: ${WHITE}${INSTALL_DIR}${NC}"
    echo -e " • File Rahasia:        ${WHITE}${INSTALL_DIR}/.env (Jaga kerahasiaan file ini!)${NC}"
    echo -e " • Diagnostik:          ${WHITE}bash ${INSTALL_DIR}/troubleshoot.sh${NC}"
    echo ""
    echo -e "${CYAN}💾 KONFIGURASI BACKUP & UPDATE:${NC}"
    echo -e " • Backup Otomatis:     ${WHITE}Setiap hari jam 2 pagi${NC}"
    echo -e " • Lokasi Backup:       ${WHITE}${INSTALL_DIR}/files/backup_full/${NC}"
    echo -e " • Auto-Update:         ${WHITE}$([[ "$ENABLE_AUTO_UPDATE" == "true" ]] && echo "Aktif (setiap 12 jam)" || echo "Nonaktif")${NC}"
    echo -e " • Health Check:        ${WHITE}Setiap 5 menit${NC}"
    echo ""
    echo -e "${CYAN}📋 PERINTAH PENTING:${NC}"
    echo -e " • Melihat Log:         ${WHITE}cd ${INSTALL_DIR} && docker compose logs -f${NC}"
    echo -e " • Restart Layanan:     ${WHITE}cd ${INSTALL_DIR} && docker compose restart${NC}"
    echo -e " • Backup Manual:       ${WHITE}bash ${INSTALL_DIR}/backup-manual.sh${NC}"
    echo -e " • Update Manual:       ${WHITE}bash ${INSTALL_DIR}/update-n8n.sh${NC}"
    echo ""
    echo -e "${YELLOW}Terima kasih telah menggunakan skrip ini!${NC}"
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
