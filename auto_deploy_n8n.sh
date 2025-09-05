#!/bin/bash

# =============================================================================
# 🚀 N8N AUTOMATIC INSTALLATION SCRIPT
# =============================================================================
# =============================================================================

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m' # No Color

# Global variables
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

# =============================================================================
# UTILITY FUNCTIONS
# =============================================================================

show_banner() {
    clear
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${WHITE}                 🚀 N8N AUTOMATIC INSTALLATION SCRIPT 🚀                    ${CYAN}║${NC}"
    echo -e "${CYAN}╠══════════════════════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${CYAN}║${WHITE} ✨ Installs N8N + FFmpeg + yt-dlp                                         ${CYAN}║${NC}"
    echo -e "${CYAN}║${WHITE} ✨ Features Telegram/G-Drive Backups & Auto-Updates                       ${CYAN}║${NC}"
    echo -e "${CYAN}║${WHITE} ✅ Includes options to restore from backup during installation.          ${CYAN}║${NC}"
    echo -e "${CYAN}║${WHITE} 🐞 Fixes for SSL Rate Limits & sets timezone to GMT+7.                    ${CYAN}║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] $1${NC}"
}

error() {
    echo -e "${RED}[ERROR] $1${NC}" >&2
}

warning() {
    echo -e "${YELLOW}[WARNING] $1${NC}"
}

info() {
    echo -e "${BLUE}[INFO] $1${NC}"
}

success() {
    echo -e "${GREEN}[SUCCESS] $1${NC}"
}

# =============================================================================
# ARGUMENT PARSING
# =============================================================================

show_help() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "OPTIONS:"
    echo "  -h, --help          Show this help message"
    echo "  -d, --dir DIR       Set installation directory (default: /home/n8n)"
    echo "  -c, --clean         Remove old installation before starting"
    echo "  -s, --skip-docker   Skip Docker installation (if already installed)"
    echo "  -l, --local         Install in Local Mode (no domain needed)"
    echo ""
    echo "Examples:"
    echo "  $0                  # Standard installation with a domain"
    echo "  $0 --local         # Install in Local Mode"
    echo "  $0 --clean         # Remove old installation and start fresh"
    echo "  $0 -d /opt/n8n     # Install into the /opt/n8n directory"
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
            -l|--local)
                LOCAL_MODE=true
                shift
                ;;
            *)
                error "Invalid argument: $1"
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
        error "This script needs to be run as root. Please use: sudo $0"
        exit 1
    fi
}

check_os() {
    if [[ ! -f /etc/os-release ]]; then
        error "Could not determine the operating system."
        exit 1
    fi
    
    . /etc/os-release
    if [[ "$ID" != "ubuntu" ]]; then
        warning "This script is designed for Ubuntu. Your current OS is: $ID"
        read -p "Do you want to continue anyway? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    fi
}

detect_environment() {
    if grep -q Microsoft /proc/version 2>/dev/null; then
        info "WSL environment detected."
        export WSL_ENV=true
    else
        export WSL_ENV=false
    fi
}

check_docker_compose() {
    if docker compose version &> /dev/null 2>&1; then
        export DOCKER_COMPOSE="docker compose"
        info "Using docker compose (v2)."
    elif command -v docker-compose &> /dev/null; then
        export DOCKER_COMPOSE="docker-compose"
        warning "Found docker-compose v1. We'll try to install the v2 plugin, as it's preferred."
    else
        export DOCKER_COMPOSE=""
    fi
}

# =============================================================================
# SWAP MANAGEMENT
# =============================================================================

setup_swap() {
    log "🔄 Setting up swap memory..."
    
    # Get total RAM in GB
    local ram_gb=$(free -g | awk '/^Mem:/{print $2}')
    local swap_size
    
    # Calculate swap size based on RAM
    if [[ $ram_gb -le 2 ]]; then
        swap_size="2G"
    elif [[ $ram_gb -le 4 ]]; then
        swap_size="4G"
    else
        swap_size="4G"
    fi
    
    # Check if swap already exists
    if swapon --show | grep -q "/swapfile"; then
        info "Swap file already exists. Skipping."
        return 0
    fi
    
    # Create swap file
    log "Creating a ${swap_size} swap file..."
    fallocate -l $swap_size /swapfile || dd if=/dev/zero of=/swapfile bs=1024 count=$((${swap_size%G} * 1024 * 1024))
    chmod 600 /swapfile
    mkswap /swapfile
    swapon /swapfile
    
    # Make swap permanent
    if ! grep -q "/swapfile" /etc/fstab; then
        echo "/swapfile none swap sw 0 0" >> /etc/fstab
    fi
    
    success "Successfully set up a ${swap_size} swap file."
}

# =============================================================================
# RCLONE & RESTORE FUNCTIONS (IMPROVED)
# =============================================================================

install_rclone() {
    if command -v rclone &> /dev/null; then
        info "rclone is already installed."
        return 0
    fi
    log "📦 Installing rclone..."
    apt-get update && apt-get install -y unzip
    curl https://rclone.org/install.sh | sudo bash
    success "rclone has been installed."
}

setup_rclone_config() {
    if rclone listremotes | grep -q "^${RCLONE_REMOTE_NAME}:"; then
        info "Rclone remote '${RCLONE_REMOTE_NAME}' is already configured. Skipping."
        return 0
    fi

    echo ""
    echo -e "${YELLOW}╔══════════════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${YELLOW}║${WHITE}             ⚙️ HOW TO CONFIGURE RCLONE WITH GOOGLE DRIVE ⚙️              ${YELLOW}║${NC}"
    echo -e "${YELLOW}╚══════════════════════════════════════════════════════════════════════════════╝${NC}"
    echo "Let's connect this script to your Google Drive account."
    echo "The rclone configuration tool will start. Please follow these simple steps:"
    echo ""
    echo -e "1.  When prompted, type ${CYAN}n${NC} and press Enter for a 'New remote'."
    echo -e "2.  For 'name', type exactly: ${WHITE}${RCLONE_REMOTE_NAME}${NC} and press Enter. (This is important!)"
    echo -e "3.  For 'Storage', find 'drive' (Google Drive) in the list and enter its number."
    echo -e "4.  Press Enter to leave 'client_id' and 'client_secret' blank."
    echo -e "5.  For 'scope', type ${WHITE}1${NC} and press Enter for full access."
    echo -e "6.  Press Enter to leave 'root_folder_id' and 'service_account_file' blank."
    echo -e "7.  For 'Edit advanced config?', type ${WHITE}n${NC} and press Enter."
    echo -e "8.  For 'Use auto config?', type ${WHITE}n${NC} and press Enter. (Important for SSH users!)"
    echo -e "9.  ${RED}rclone will give you a link. Copy this link and open it in a browser on your computer.${NC}"
    echo -e "10. Log in to your Google account and grant rclone permission."
    echo -e "11. Google will give you a verification code. ${RED}Copy this code and paste it back into your terminal.${NC}"
    echo -e "12. For 'Configure this as a team drive?', type ${WHITE}n${NC} and press Enter."
    echo -e "13. Confirm with ${WHITE}y${NC} ('Yes this is OK')."
    echo -e "14. Press ${WHITE}q${NC} to quit the config tool."
    echo ""
    read -p "Press Enter when you're ready to start the rclone config..."

    rclone config

    if ! rclone listremotes | grep -q "^${RCLONE_REMOTE_NAME}:"; then
        error "Rclone remote '${RCLONE_REMOTE_NAME}' was not configured correctly. Please try again."
        exit 1
    fi
    success "Great! Rclone remote '${RCLONE_REMOTE_NAME}' is configured."
}


get_restore_option() {
    echo ""
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${WHITE}                           🔄 RESTORE DATA OPTION                           ${CYAN}║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    read -p "🔄 Would you like to restore n8n data from an existing backup? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        RESTORE_MODE=false
        return 0
    fi

    RESTORE_MODE=true
    echo "Where is your backup file located?"
    echo -e "  ${GREEN}1. On this local machine (.tar.gz file)${NC}"
    echo -e "  ${GREEN}2. In Google Drive (requires rclone setup)${NC}"
    read -p "Your choice [1]: " source_choice

    if [[ "$source_choice" == "2" ]]; then
        RESTORE_SOURCE="gdrive"
        install_rclone
        setup_rclone_config
        
        read -p "📝 Enter the folder name in Google Drive where backups are stored [n8n_backups]: " GDRIVE_FOLDER_INPUT
        if [[ -n "$GDRIVE_FOLDER_INPUT" ]]; then GDRIVE_BACKUP_FOLDER="$GDRIVE_FOLDER_INPUT"; fi

        log "🔍 Fetching backup list from Google Drive..."
        mapfile -t backups < <(rclone lsf "$RCLONE_REMOTE_NAME:$GDRIVE_BACKUP_FOLDER" --include "*.tar.gz" | sort -r)
        if [ ${#backups[@]} -eq 0 ]; then
            error "Could not find any backup files in the '$GDRIVE_BACKUP_FOLDER' folder on Google Drive."
            exit 1
        fi

        echo "Please choose a backup file to restore:"
        for i in "${!backups[@]}"; do
            echo "  $((i+1)). ${backups[$i]}"
        done
        read -p "Enter the number of the backup file: " file_idx
        
        selected_backup="${backups[$((file_idx-1))]}"
        if [[ -z "$selected_backup" ]]; then
            error "Invalid selection."
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
            read -p "📁 Please enter the full path to your local backup file (.tar.gz): " RESTORE_FILE_PATH
            if [[ -f "$RESTORE_FILE_PATH" ]]; then
                break
            else
                error "File not found. Please double-check the path."
            fi
        done
    fi
    
    # Validate backup file
    log "🔍 Verifying backup file integrity..."
    if tar -tzf "$RESTORE_FILE_PATH" &>/dev/null; then
        success "Backup file is valid."
    else
        error "The backup file appears to be corrupted or in the wrong format."
        exit 1
    fi
}

perform_restore() {
    if [[ "$RESTORE_MODE" != "true" ]]; then return 0; fi
    
    log "🔄 Starting the restore process from: $RESTORE_FILE_PATH"
    
    # Ensure target directory exists
    mkdir -p "$INSTALL_DIR/files"
    
    # Clean target directory
    log "🧹 Cleaning up old data directory..."
    rm -rf "$INSTALL_DIR/files/"* 2>/dev/null || true
    
    # Extract backup
    log "📦 Extracting backup file..."
    local temp_extract_dir="/tmp/n8n_restore_extract_$$"
    mkdir -p "$temp_extract_dir"
    
    if tar -xzvf "$RESTORE_FILE_PATH" -C "$temp_extract_dir" > /tmp/extract_log.txt 2>&1; then
        log "Backup file contents:"
        ls -la "$temp_extract_dir/"
        
        # Find the backup content directory
        local backup_content_dir=""
        if [[ -d "$temp_extract_dir/n8n_backup_"* ]]; then
            backup_content_dir=$(find "$temp_extract_dir" -maxdepth 1 -type d -name "n8n_backup_*" | head -1)
        elif [[ -d "$temp_extract_dir/credentials" ]]; then
            backup_content_dir="$temp_extract_dir"
        fi
        
        if [[ -n "$backup_content_dir" && -d "$backup_content_dir" ]]; then
            log "Found backup content in: $backup_content_dir"
            
            if [[ -d "$backup_content_dir/credentials" ]]; then
                log "Restoring database and encryption key..."
                cp -a "$backup_content_dir/credentials/"* "$INSTALL_DIR/files/" 2>/dev/null || true
                
                if [[ -f "$INSTALL_DIR/files/database.sqlite" ]]; then
                    chmod 644 "$INSTALL_DIR/files/database.sqlite"
                    chown 1000:1000 "$INSTALL_DIR/files/database.sqlite"
                fi
            fi
            
            if [[ -d "$backup_content_dir/config" ]]; then
                log "Restoring configuration files..."
                [[ -f "$INSTALL_DIR/docker-compose.yml" ]] && cp "$INSTALL_DIR/docker-compose.yml" "$INSTALL_DIR/docker-compose.yml.bak"
                [[ -f "$INSTALL_DIR/Caddyfile" ]] && cp "$INSTALL_DIR/Caddyfile" "$INSTALL_DIR/Caddyfile.bak"
                cp -a "$backup_content_dir/config/"* "$INSTALL_DIR/" 2>/dev/null || true
            fi
        else
            error "Invalid backup structure. Could not find the content directory."
            cat /tmp/extract_log.txt
            rm -rf "$temp_extract_dir"
            exit 1
        fi
        
        rm -rf "$temp_extract_dir"
        if [[ "$RESTORE_SOURCE" == "gdrive" ]]; then
            rm -rf "/tmp/n8n_restore"
        fi
        
        chown -R 1000:1000 "$INSTALL_DIR/files/"
        
        success "✅ Data restore completed successfully!"
    else
        error "Failed to extract the backup file. Error details:"
        cat /tmp/extract_log.txt
        rm -rf "$temp_extract_dir"
        exit 1
    fi
}

# =============================================================================
# USER INPUT FUNCTIONS
# =============================================================================

get_installation_mode() {
    if [[ "$LOCAL_MODE" == "true" ]]; then
        return 0
    fi
    
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${WHITE}                         🏠 CHOOSE INSTALLATION MODE                        ${CYAN}║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${WHITE}Please choose your installation mode:${NC}"
    echo -e "  ${GREEN}1. Production Mode (with a domain + SSL)${NC}"
    echo -e "     • Requires a domain name pointing to this server."
    echo -e "     • Automatically sets up a free SSL certificate (HTTPS)."
    echo -e "     • Recommended for live, production environments."
    echo ""
    echo -e "  ${GREEN}2. Local Mode (no domain required)${NC}"
    echo -e "     • Runs on localhost (accessible via server IP)."
    echo -e "     • Does not use an SSL certificate (HTTP)."
    echo -e "     • Great for development or testing."
    echo ""
    
    read -p "🏠 Would you like to install in Local Mode? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        LOCAL_MODE=true
        info "OK, we'll use Local Mode."
    else
        LOCAL_MODE=false
        info "Got it, we'll use Production Mode."
    fi
}

get_domain_input() {
    if [[ "$LOCAL_MODE" == "true" ]]; then
        DOMAIN="localhost"
        info "Local Mode: Using 'localhost'."
        return 0
    fi
    
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${WHITE}                           🌐 DOMAIN CONFIGURATION                            ${CYAN}║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    
    while true; do
        read -p "🌐 Please enter your main domain for N8N (e.g., n8n.example.com): " DOMAIN
        if [[ -n "$DOMAIN" && "$DOMAIN" =~ ^[a-zA-Z0-9][a-zA-Z0-9.-]*[a-zA-Z0-9]$ ]]; then
            break
        else
            error "That doesn't look like a valid domain. Please try again."
        fi
    done
    
    info "N8N Domain: ${DOMAIN}"
}

get_cleanup_option() {
    if [[ "$CLEAN_INSTALL" == "true" ]]; then
        return 0
    fi
    
    echo ""
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${WHITE}                             🗑️ CLEANUP OPTION                              ${CYAN}║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    
    if [[ -d "$INSTALL_DIR" ]]; then
        warning "Looks like an old n8n installation exists at: $INSTALL_DIR"
        read -p "🗑️ Do you want to completely remove the old installation first? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            CLEAN_INSTALL=true
        fi
    fi
}

get_backup_config() {
    if [[ "$LOCAL_MODE" == "true" ]]; then
        info "Local Mode: Skipping automatic backup configuration."
        return 0
    fi

    echo ""
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${WHITE}                      💾 AUTOMATIC BACKUP SETUP                         ${CYAN}║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${WHITE}Our backup system can:${NC}"
    echo -e "  🔄 Automatically back up your workflows & credentials daily."
    echo -e "  📱 Send notifications and the backup file via Telegram."
    echo -e "  ☁️ Securely upload the backup file to Google Drive."
    echo -e "  🗂️ Automatically clean up old backups."
    echo ""

    # Telegram Backup
    read -p "📱 Do you want to set up backups via Telegram? (Y/n): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Nn]$ ]]; then
        ENABLE_TELEGRAM=true
        echo ""
        echo -e "${YELLOW}🤖 How to get a Telegram Bot Token:${NC}"
        echo -e "  1. In Telegram, search for @BotFather and start a chat."
        echo -e "  2. Send the /newbot command and follow the instructions."
        echo -e "  3. Copy the Bot Token he gives you."
        echo ""
        while true; do
            read -p "🤖 Please enter your Telegram Bot Token: " TELEGRAM_BOT_TOKEN
            if [[ -n "$TELEGRAM_BOT_TOKEN" ]]; then break; fi
        done
        
        echo ""
        echo -e "${YELLOW}🆔 How to get your Chat ID:${NC}"
        echo -e "  • Search for @userinfobot and send /start to get your user ID."
        echo ""
        while true; do
            read -p "🆔 Please enter your Telegram Chat ID: " TELEGRAM_CHAT_ID
            if [[ -n "$TELEGRAM_CHAT_ID" ]]; then break; fi
        done
        success "Great, Telegram Backup is configured."
    fi

    # Google Drive Backup
    read -p "☁️ Do you want to set up backups to Google Drive? (Y/n): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Nn]$ ]]; then
        ENABLE_GDRIVE_BACKUP=true
        install_rclone
        setup_rclone_config
        read -p "📝 Enter a folder name in Google Drive for your backups [n8n_backups]: " GDRIVE_FOLDER_INPUT
        if [[ -n "$GDRIVE_FOLDER_INPUT" ]]; then GDRIVE_BACKUP_FOLDER="$GDRIVE_FOLDER_INPUT"; fi
        success "OK, Google Drive Backup is configured."
    fi
}

get_auto_update_config() {
    if [[ "$LOCAL_MODE" == "true" ]]; then
        info "Local Mode: Skipping Auto-Update setup."
        ENABLE_AUTO_UPDATE=false
        return 0
    fi
    
    echo ""
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${WHITE}                           🔄 AUTO-UPDATE                                     ${CYAN}║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${WHITE}The auto-update feature will:${NC}"
    echo -e "  🔄 Automatically check for n8n updates every 12 hours."
    echo -e "  📦 Update yt-dlp, FFmpeg, and other dependencies."
    echo -e "  🔒 Perform a backup before updating."
    echo -e "  📱 Send a Telegram notification on success or failure."
    echo ""
    
    read -p "🔄 Do you want to enable Auto-Update? (Y/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Nn]$ ]]; then
        ENABLE_AUTO_UPDATE=false
    else
        ENABLE_AUTO_UPDATE=true
        success "OK, Auto-Update has been enabled."
    fi
}

# =============================================================================
# DNS VERIFICATION
# =============================================================================

verify_dns() {
    if [[ "$LOCAL_MODE" == "true" ]]; then
        info "Local Mode: Skipping DNS check."
        return 0
    fi
    
    log "🔍 Checking DNS for ${DOMAIN}..."
    
    # Get server IP
    local server_ip=$(curl -s https://api.ipify.org || curl -s http://ipv4.icanhazip.com || echo "unknown")
    info "Your server's public IP is: ${server_ip}"
    
    # Check domain DNS
    local domain_ip=$(dig +short "$DOMAIN" A | tail -n1)
    
    info "The IP for ${DOMAIN} is: ${domain_ip:-'not found'}"
    
    if [[ "$domain_ip" != "$server_ip" ]]; then
        warning "DNS doesn't seem to be pointing to this server yet!"
        echo ""
        echo -e "${YELLOW}How to configure your DNS:${NC}"
        echo -e "  1. Log in to your domain registrar's website."
        echo -e "  2. Create an 'A' record for your domain:"
        echo -e "     • Host/Name: ${DOMAIN}"
        echo -e "     • Value/Points to: ${server_ip}"
        echo -e "  3. It might take a few minutes (or longer) for the change to take effect."
        echo ""
        
        read -p "🤔 Do you want to continue with the installation anyway? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    else
        success "DNS looks good!"
    fi
}

# =============================================================================
# CLEANUP FUNCTIONS
# =============================================================================

cleanup_old_installation() {
    if [[ "$CLEAN_INSTALL" != "true" ]]; then
        return 0
    fi
    
    log "🗑️ Removing old installation..."
    
    # Stop and remove containers
    if [[ -d "$INSTALL_DIR" ]]; then
        cd "$INSTALL_DIR"
        if [[ -n "$DOCKER_COMPOSE" ]]; then
            $DOCKER_COMPOSE down --volumes --remove-orphans 2>/dev/null || true
        fi
    fi
    
    # Remove Docker images
    docker rmi n8n-custom-ffmpeg:latest 2>/dev/null || true
    
    # Remove installation directory
    rm -rf "$INSTALL_DIR"
    
    # Remove cron jobs
    crontab -l 2>/dev/null | grep -v "/home/n8n" | crontab - 2>/dev/null || true
    
    success "Old installation has been removed."
}

# =============================================================================
# DOCKER INSTALLATION
# =============================================================================

install_docker() {
    if [[ "$SKIP_DOCKER" == "true" ]]; then
        info "Skipping Docker installation as requested."
        return 0
    fi
    
    if command -v docker &> /dev/null; then
        info "Docker is already installed."
        
        if ! docker info &> /dev/null; then
            log "Starting the Docker daemon..."
            systemctl start docker
            systemctl enable docker
        fi
        
        if docker compose version &> /dev/null 2>&1; then
            export DOCKER_COMPOSE="docker compose"
        else
            log "Installing the docker compose plugin (v2)..."
            apt-get update
            apt-get install -y docker-compose-plugin
            if docker compose version &> /dev/null 2>&1; then
                export DOCKER_COMPOSE="docker compose"
                info "Switched to using docker compose (v2)."
            else
                if command -v docker-compose &> /dev/null; then
                    export DOCKER_COMPOSE="docker-compose"
                    warning "Only found docker-compose v1. We recommend installing the v2 plugin to avoid potential issues."
                else
                    export DOCKER_COMPOSE=""
                fi
            fi
        fi
        
        return 0
    fi
    
    log "📦 Installing Docker..."
    
    apt-get update
    apt-get install -y apt-transport-https ca-certificates curl gnupg lsb-release
    
    install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
    chmod a+r /etc/apt/keyrings/docker.asc
    
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
    
    apt-get update
    apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    
    systemctl start docker
    systemctl enable docker
    
    usermod -aG docker $SUDO_USER 2>/dev/null || true
    
    export DOCKER_COMPOSE="docker compose"
    success "Docker installed successfully."
}

# =============================================================================
# PROJECT SETUP
# =============================================================================

create_project_structure() {
    log "📁 Creating project directory structure..."
    
    mkdir -p "$INSTALL_DIR"
    cd "$INSTALL_DIR"
    
    # Create directories with proper permissions
    mkdir -p files/backup_full
    mkdir -p files/temp
    mkdir -p files/youtube_content_anylystic
    mkdir -p logs
    
    # Create log files
    touch logs/backup.log
    touch logs/update.log
    touch logs/cron.log
    touch logs/health.log
    
    success "Directory structure created."
}

create_n8n_config_file() {
    log "⚙️  Creating custom N8N config file (config.js) for proxy fix..."
    
    cat > "$INSTALL_DIR/config.js" << 'EOF'
module.exports = {
  // Memberitahu n8n untuk mempercayai header proxy yang dikirim oleh Caddy.
  // Ini adalah pengganti dari variabel lingkungan N8N_TRUST_PROXY.
  proxy: 'caddy',
};
EOF
    
    success "Custom config.js created successfully."
}

create_dockerfile() {
    log "🐳 Creating a stable Dockerfile for N8N..."
    
    cat > "$INSTALL_DIR/Dockerfile" << 'EOF'
FROM n8nio/n8n:latest

USER root

# =============================================================================
# STABLE & FIXED VERSION
# - Added retry mechanism for apk update to handle network timeouts.
# - Optimized package installation.
# - Added fallbacks for potentially problematic packages.
# =============================================================================

# Update package index with a retry mechanism
RUN for i in 1 2 3; do \
        apk update && break || sleep 2; \
    done

# Install basic packages with error handling
RUN apk add --no-cache \
    ffmpeg \
    python3 \
    python3-dev \
    py3-pip \
    curl \
    wget \
    git \
    build-base \
    linux-headers \
    ca-certificates \
    && rm -rf /var/cache/apk/* /tmp/* /var/tmp/*

# Install yt-dlp with a retry mechanism
RUN for i in 1 2 3; do \
        pip3 install --break-system-packages --no-cache-dir --timeout=60 yt-dlp && break || \
        (echo "Retry $i failed, waiting..." && sleep 5); \
    done

# === Menyalin file config.js untuk mengatasi masalah proxy ===
COPY config.js /home/node/.n8n/
# =============================================================

# Create directories and set final permissions for ALL files (termasuk config.js)
RUN mkdir -p /home/node/.n8n/nodes /data/youtube_content_anylystic && \
    chown -R 1000:1000 /home/node/.n8n /data && \
    chmod -R 755 /home/node/.n8n /data

USER node

# Health check with a shorter timeout
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD curl -f http://localhost:5678/healthz || exit 1

WORKDIR /data
EOF
    
    success "Dockerfile for N8N (stable version) created."
}

create_docker_compose() {
    log "🐳 Creating docker-compose.yml..."
    
    if [[ "$LOCAL_MODE" == "true" ]]; then
        # Local Mode - No Caddy, direct port exposure
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
      - NODE_ENV=production
      - WEBHOOK_URL=http://localhost:5678/
      - GENERIC_TIMEZONE=Asia/Jakarta
      - N8N_METRICS=true
      - N8N_LOG_LEVEL=info
      - N8N_LOG_OUTPUT=console
      - N8N_USER_FOLDER=/home/node
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
EOF

    else
        # Production Mode - With Caddy reverse proxy
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
      - N8N_HOST=0.0.0.0
      - N8N_PORT=5678
      - N8N_PROTOCOL=http
      - NODE_ENV=production
      - WEBHOOK_URL=https://${DOMAIN}/
      - GENERIC_TIMEZONE=Asia/Jakarta
      # - N8N_TRUST_PROXY=caddy
      - N8N_METRICS=true
      - N8N_LOG_LEVEL=info
      - N8N_LOG_OUTPUT=console
      - N8N_USER_FOLDER=/home/node
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
EOF
    fi

    cat >> "$INSTALL_DIR/docker-compose.yml" << 'EOF'

networks:
  n8n_network:
    driver: bridge
EOF
    
    success "docker-compose.yml created."
}

create_caddyfile() {
    if [[ "$LOCAL_MODE" == "true" ]]; then
        info "Local Mode: Skipping Caddyfile creation."
        return 0
    fi
    
    log "🌐 Creating Caddyfile for web server..."
    
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
    
    # Custom error pages
    handle_errors {
        @502 expression {http.error.status_code} == 502
        handle @502 {
            respond "N8N service is starting up. Please wait a moment and refresh." 502
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

# =============================================================================
# BACKUP SYSTEM (FIXED)
# =============================================================================

create_backup_scripts() {
    log "💾 Creating backup system..."
    
    # Main backup script
    cat > "$INSTALL_DIR/backup-workflows.sh" << 'EOF'
#!/bin/bash

# =============================================================================
# N8N BACKUP SCRIPT - FIXED VERSION
# =============================================================================

set -e

BACKUP_DIR="/home/n8n/files/backup_full"
LOG_FILE="/home/n8n/logs/backup.log"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
BACKUP_NAME="n8n_backup_$TIMESTAMP"
TEMP_DIR="/tmp/$BACKUP_NAME"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] $1${NC}" | tee -a "$LOG_FILE"
}

error() {
    echo -e "${RED}[ERROR] $1${NC}" | tee -a "$LOG_FILE"
}

# Create directories
mkdir -p "$BACKUP_DIR"
mkdir -p "$(dirname "$LOG_FILE")"

# Check Docker Compose command
if command -v docker-compose &> /dev/null; then
    DOCKER_COMPOSE="docker-compose"
elif docker compose version &> /dev/null; then
    DOCKER_COMPOSE="docker compose"
else
    error "Docker Compose not found!"
    exit 1
fi

# Create backup directory
mkdir -p "$BACKUP_DIR"
mkdir -p "$TEMP_DIR"

log "🔄 Starting N8N backup..."

# Backup database and encryption key
log "💾 Backing up database and key..."
mkdir -p "$TEMP_DIR/credentials"

# Copy database with error handling
if [[ -f "/home/n8n/files/database.sqlite" ]]; then
    cp "/home/n8n/files/database.sqlite" "$TEMP_DIR/credentials/" || {
        error "Failed to copy database file."
        exit 1
    }
else
    DB_PATH=$(find /home/n8n/files -name "database.sqlite" -type f 2>/dev/null | head -1)
    if [[ -n "$DB_PATH" ]]; then
        cp "$DB_PATH" "$TEMP_DIR/credentials/"
    else
        error "database.sqlite not found."
    fi
fi

# Copy encryption key
cp "/home/n8n/files/encryptionKey" "$TEMP_DIR/credentials/" 2>/dev/null || log "encryptionKey not found (this is normal on first run)."

# Backup config files
log "🔧 Backing up config files..."
mkdir -p "$TEMP_DIR/config"
cp /home/n8n/docker-compose.yml "$TEMP_DIR/config/" 2>/dev/null || true
cp /home/n8n/Caddyfile "$TEMP_DIR/config/" 2>/dev/null || true
cp /home/n8n/telegram_config.txt "$TEMP_DIR/config/" 2>/dev/null || true
cp /home/n8n/gdrive_config.txt "$TEMP_DIR/config/" 2>/dev/null || true

# Create metadata
log "📊 Creating metadata file..."
cat > "$TEMP_DIR/backup_metadata.json" << EOL
{
    "backup_date": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
    "backup_name": "$BACKUP_NAME",
    "n8n_version": "$(docker exec n8n-container n8n --version 2>/dev/null || echo 'unknown')",
    "backup_type": "full",
    "files_included": $(find "$TEMP_DIR" -type f | wc -l)
}
EOL

# Create compressed backup
log "📦 Creating compressed backup file..."
cd /tmp
tar -czf "$BACKUP_DIR/$BACKUP_NAME.tar.gz" "$BACKUP_NAME/" || {
    error "Failed to create compressed backup file."
    rm -rf "$TEMP_DIR"
    exit 1
}

# Verify backup
log "🔍 Verifying backup file..."
if tar -tzf "$BACKUP_DIR/$BACKUP_NAME.tar.gz" >/dev/null 2>&1; then
    log "✅ Backup file is valid."
else
    error "Backup file is corrupted."
    rm -rf "$TEMP_DIR"
    exit 1
fi

# Get backup size
BACKUP_SIZE=$(ls -lh "$BACKUP_DIR/$BACKUP_NAME.tar.gz" | awk '{print $5}')
log "✅ Backup complete: $BACKUP_NAME.tar.gz ($BACKUP_SIZE)"

# Cleanup temp directory
rm -rf "$TEMP_DIR"

# Keep only last 30 local backups
log "🧹 Cleaning up old local backups..."
cd "$BACKUP_DIR"
ls -t n8n_backup_*.tar.gz 2>/dev/null | tail -n +31 | xargs -r rm -f

# Send to Telegram if configured
if [[ -f "/home/n8n/telegram_config.txt" ]]; then
    source "/home/n8n/telegram_config.txt"
    
    if [[ -n "$TELEGRAM_BOT_TOKEN" && -n "$TELEGRAM_CHAT_ID" ]]; then
        log "📱 Sending Telegram notification..."
        MESSAGE="🔄 *N8N Backup Completed*
📅 Date: $(date +'%Y-%m-%d %H:%M:%S')
📦 File: \`$BACKUP_NAME.tar.gz\`
💾 Size: $BACKUP_SIZE
📊 Status: ✅ Success"
        
        curl -s -X POST "https://api.telegram.org/bot$TELEGRAM_BOT_TOKEN/sendMessage" \
            -d chat_id="$TELEGRAM_CHAT_ID" \
            -d text="$MESSAGE" \
            -d parse_mode="Markdown" > /dev/null || log "Failed to send Telegram notification."
    fi
fi

# Upload to Google Drive if configured
if [[ -f "/home/n8n/gdrive_config.txt" ]]; then
    source "/home/n8n/gdrive_config.txt"
    if [[ -n "$RCLONE_REMOTE_NAME" && -n "$GDRIVE_BACKUP_FOLDER" ]]; then
        log "☁️ Uploading to Google Drive..."
        rclone copy "$BACKUP_DIR/$BACKUP_NAME.tar.gz" "$RCLONE_REMOTE_NAME:$GDRIVE_BACKUP_FOLDER" --progress || log "Google Drive upload failed."
        log "🧹 Cleaning up old Google Drive backups (older than 30 days)..."
        rclone delete --min-age 30d "$RCLONE_REMOTE_NAME:$GDRIVE_BACKUP_FOLDER" || true
    fi
fi

log "🎉 Backup process completed successfully!"
EOF

    chmod +x "$INSTALL_DIR/backup-workflows.sh"
    
    # Manual backup test script
    cat > "$INSTALL_DIR/backup-manual.sh" << 'EOF'
#!/bin/bash

echo "🧪 MANUAL BACKUP TEST"
echo "===================="
echo ""

cd /home/n8n

echo "📋 System Info:"
echo "• Time: $(date)"
echo "• Disk usage: $(df -h /home/n8n | tail -1 | awk '{print $5}')"
echo "• Memory: $(free -h | grep Mem | awk '{print $3"/"$2}')"
echo ""

echo "🔄 Running backup test..."
./backup-workflows.sh

echo ""
echo "📊 Backup Results:"
ls -lah /home/n8n/files/backup_full/n8n_backup_*.tar.gz 2>/dev/null | tail -5

echo ""
echo "✅ Manual backup test completed!"
EOF

    chmod +x "$INSTALL_DIR/backup-manual.sh"
    
    success "Backup system created."
}

create_update_script() {
    log "🔄 Creating auto-update script..."
    
    cat > "$INSTALL_DIR/update-n8n.sh" << 'EOF'
#!/bin/bash

# =============================================================================
# N8N AUTO-UPDATE SCRIPT - FIXED VERSION
# =============================================================================

set -e

LOG_FILE="/home/n8n/logs/update.log"
TIMESTAMP=$(date +"%Y-%m-%d %H:%M:%S")

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

mkdir -p "$(dirname "$LOG_FILE")"

log() {
    echo -e "${GREEN}[$TIMESTAMP] $1${NC}" | tee -a "$LOG_FILE"
}

error() {
    echo -e "${RED}[$TIMESTAMP] [ERROR] $1${NC}" | tee -a "$LOG_FILE"
}

send_telegram() {
    if [[ -f "/home/n8n/telegram_config.txt" ]]; then
        source "/home/n8n/telegram_config.txt"
        if [[ -n "$TELEGRAM_BOT_TOKEN" && -n "$TELEGRAM_CHAT_ID" ]]; then
            curl -s -X POST "https://api.telegram.org/bot$TELEGRAM_BOT_TOKEN/sendMessage" \
                -d chat_id="$TELEGRAM_CHAT_ID" \
                -d text="$1" \
                -d parse_mode="Markdown" > /dev/null || true
        fi
    fi
}

detect_compose_cmd() {
    if docker compose version &> /dev/null 2>&1; then
        DOCKER_COMPOSE="docker compose"
    elif command -v docker-compose &> /dev/null; then
        DOCKER_COMPOSE="docker-compose"
    else
        DOCKER_COMPOSE=""
    fi
}

detect_compose_cmd

if [[ -z "$DOCKER_COMPOSE" ]]; then
    error "Docker Compose not found!"
    send_telegram "❌ *N8N Update Failed*\nDocker Compose could not be found.\nTime: $TIMESTAMP"
    exit 1
fi

# If both exist, force v2
if command -v docker-compose &> /dev/null && docker compose version &> /dev/null 2>&1; then
    DOCKER_COMPOSE="docker compose"
fi

cd /home/n8n

# Validate docker-compose.yml
if ! $DOCKER_COMPOSE config -q; then
    error "docker-compose.yml is invalid."
    send_telegram "❌ *N8N Update Failed*\ndocker-compose.yml is invalid.\nTime: $TIMESTAMP"
    exit 1
fi

log "🔄 Starting N8N auto-update..."

log "💾 Backing up before updating..."
./backup-workflows.sh || {
    error "Backup failed. Aborting update."
    send_telegram "❌ *N8N Update Failed*\nBackup process failed.\nTime: $TIMESTAMP"
    exit 1
}

OLD_VERSION=$(docker exec n8n-container n8n --version 2>/dev/null || echo "unknown")

log "📦 Pulling latest Docker images..."
if ! $DOCKER_COMPOSE pull; then
    error "Failed to pull new images."
    send_telegram "❌ *N8N Update Failed*\nFailed to pull new Docker images.\nTime: $TIMESTAMP"
    exit 1
fi

log "📺 Updating yt-dlp..."
docker exec n8n-container pip3 install --break-system-packages -U yt-dlp || log "Failed to update yt-dlp (non-critical)."

log "🔄 Restarting services..."
if ! $DOCKER_COMPOSE up -d --remove-orphans; then
    if [[ "$DOCKER_COMPOSE" == "docker-compose" ]]; then
        log "⚠️ Encountered an issue with docker-compose v1. Attempting to remove and restart containers..."
        $DOCKER_COMPOSE rm -fsv n8n || true
        $DOCKER_COMPOSE rm -fsv caddy || true
        $DOCKER_COMPOSE up -d --remove-orphans || {
            error "Failed to restart services after workaround."
            send_telegram "❌ *N8N Update Failed*\nFailed to restart services.\nTime: $TIMESTAMP"
            exit 1
        }
    else
        error "Failed to restart services."
        send_telegram "❌ *N8N Update Failed*\nFailed to restart services.\nTime: $TIMESTAMP"
        exit 1
    fi
fi

log "⏳ Waiting for services to initialize..."
sleep 30

SERVICES_STATUS=""
if docker ps | grep -q "n8n-container"; then
    log "✅ N8N container is running."
    SERVICES_STATUS="$SERVICES_STATUS\n✅ N8N: Running"
else
    error "❌ N8N container is NOT running."
    SERVICES_STATUS="$SERVICES_STATUS\n❌ N8N: Not running"
fi

if docker ps | grep -q "caddy-proxy"; then
    log "✅ Caddy container is running."
    SERVICES_STATUS="$SERVICES_STATUS\n✅ Caddy: Running"
fi

NEW_VERSION=$(docker exec n8n-container n8n --version 2>/dev/null || echo "unknown")

HEALTH_STATUS=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:5678/healthz || echo "000")
if [[ "$HEALTH_STATUS" == "200" ]]; then
    HEALTH_MSG="✅ Health check passed"
else
    HEALTH_MSG="❌ Health check failed (HTTP $HEALTH_STATUS)"
fi

MESSAGE="🔄 *N8N Auto-Update Report*\n\n📅 Time: $TIMESTAMP\n🚀 Status: ✅ Success\n📦 Version: $OLD_VERSION → $NEW_VERSION\n🏥 Health: $HEALTH_MSG\n\n📊 Services:$SERVICES_STATUS\n\n🌐 All systems are operational!"

send_telegram "$MESSAGE"
log "🎉 Auto-update completed successfully!"
log "Old version: $OLD_VERSION"
log "New version: $NEW_VERSION"
EOF
    
    chmod +x "$INSTALL_DIR/update-n8n.sh"
    
    success "Auto-update script created."
}

# =============================================================================
# TELEGRAM & GDRIVE CONFIGURATION
# =============================================================================

setup_backup_configs() {
    if [[ "$ENABLE_TELEGRAM" == "true" ]]; then
        log "📱 Saving Telegram configuration..."
        cat > "$INSTALL_DIR/telegram_config.txt" << EOF
TELEGRAM_BOT_TOKEN="$TELEGRAM_BOT_TOKEN"
TELEGRAM_CHAT_ID="$TELEGRAM_CHAT_ID"
EOF
        chmod 600 "$INSTALL_DIR/telegram_config.txt"
    fi

    if [[ "$ENABLE_GDRIVE_BACKUP" == "true" ]]; then
        log "☁️ Saving Google Drive configuration..."
        cat > "$INSTALL_DIR/gdrive_config.txt" << EOF
RCLONE_REMOTE_NAME="$RCLONE_REMOTE_NAME"
GDRIVE_BACKUP_FOLDER="$GDRIVE_BACKUP_FOLDER"
EOF
        chmod 600 "$INSTALL_DIR/gdrive_config.txt"
    fi
}

# =============================================================================
# CRON JOBS (FIXED)
# =============================================================================

setup_cron_jobs() {
    if [[ "$LOCAL_MODE" == "true" ]]; then
        info "Local Mode: Skipping cron job setup."
        return 0
    fi
    
    log "⏰ Setting up cron jobs..."
    
    # Remove existing cron jobs for n8n to avoid duplicates
    crontab -l 2>/dev/null | grep -v "/home/n8n" | crontab - 2>/dev/null || true
    
    # Create cron file
    CRON_FILE="/tmp/n8n_cron_$$"
    crontab -l 2>/dev/null > "$CRON_FILE" || true
    
    # Add backup job (daily at 2:00 AM)
    echo "0 2 * * * /home/n8n/backup-workflows.sh >> /home/n8n/logs/cron.log 2>&1" >> "$CRON_FILE"
    
    # Add auto-update job if enabled (every 12 hours)
    if [[ "$ENABLE_AUTO_UPDATE" == "true" ]]; then
        echo "0 */12 * * * /home/n8n/update-n8n.sh >> /home/n8n/logs/cron.log 2>&1" >> "$CRON_FILE"
    fi
    
    # Add health check job (every 5 minutes)
    echo "*/5 * * * * /home/n8n/health-monitor.sh >> /home/n8n/logs/health.log 2>&1" >> "$CRON_FILE"

    # Install new crontab
    crontab "$CRON_FILE"
    rm -f "$CRON_FILE"
    
    log "Cron jobs have been set:"
    crontab -l | grep "/home/n8n"
    
    success "Cron jobs set up successfully."
}

# =============================================================================
# SSL RATE LIMIT DETECTION (IMPROVED)
# =============================================================================

check_ssl_rate_limit() {
    if [[ "$LOCAL_MODE" == "true" ]]; then
        info "Local Mode: Skipping SSL check."
        return 0
    fi
    
    log "🔒 Checking SSL certificate status..."
    
    log "⏳ Waiting for Caddy to issue the SSL certificate (up to 90 seconds)..."
    sleep 90
    
    local caddy_logs=$($DOCKER_COMPOSE logs caddy 2>&1)

    if echo "$caddy_logs" | grep -q "certificate obtained successfully" || echo "$caddy_logs" | grep -q "$DOMAIN"; then
        success "✅ SSL certificate for $DOMAIN was issued successfully."
        return 0
    fi

    if echo "$caddy_logs" | grep -q "urn:ietf:params:acme:error:rateLimited"; then
        error "🚨 SSL RATE LIMIT DETECTED!"
        echo ""
        echo -e "${RED}╔══════════════════════════════════════════════════════════════════════════════╗${NC}"
        echo -e "${RED}║${WHITE}                      ⚠️ SSL RATE LIMIT DETECTED ⚠️                        ${RED}║${NC}"
        echo -e "${RED}╚══════════════════════════════════════════════════════════════════════════════╝${NC}"
        echo ""
        
        # Install python3-pip and pytz if not present, for timezone conversion
        if ! dpkg -s python3-pip >/dev/null 2>&1; then apt-get install -y python3-pip; fi
        if ! python3 -c "import pytz" >/dev/null 2>&1; then pip3 install pytz; fi

        local reset_time_local=$(python3 -c "
import re, datetime, pytz
log_data = '''$caddy_logs'''
match = re.search(r'Retry-After: (\w{3}, \d{2} \w{3} \d{4} \d{2}:\d{2}:\d{2} GMT)', log_data)
if match:
    try:
        gmt_time_str = match.group(1)
        gmt_time = datetime.datetime.strptime(gmt_time_str, '%a, %d %b %Y %H:%M:%S GMT')
        gmt_tz = pytz.timezone('GMT')
        gmt_time_aware = gmt_tz.localize(gmt_time)
        local_tz = pytz.timezone('Asia/Jakarta')
        local_time = gmt_time_aware.astimezone(local_tz)
        print(local_time.strftime('%H:%M:%S on %d-%m-%Y (Local Time)'))
    except Exception:
        print('Could not calculate, please wait 7 days.')
else:
    print('Could not determine, please wait 7 days.')
")
        
        echo -e "${YELLOW}🔍 WHAT HAPPENED:${NC}"
        echo -e "  • Let's Encrypt limits you to 5 certificates per domain per week."
        echo -e "  • Your domain has hit this free limit."
        echo ""
        echo -e "${YELLOW}📅 RATE LIMIT INFO:${NC}"
        echo -e "  • This limit should reset around: ${WHITE}$reset_time_local${NC}"
        echo ""
        
        echo -e "${YELLOW}💡 WHAT YOU CAN DO:${NC}"
        echo -e "  ${GREEN}1. USE A TEMPORARY (STAGING) SSL CERTIFICATE:${NC}"
        echo -e "     • Your n8n will work, but your browser will show a 'Not Secure' warning."
        echo -e "     • You can switch back to a real SSL certificate after the rate limit resets."
        echo ""
        echo -e "  ${GREEN}2. WAIT FOR THE RATE LIMIT TO RESET:${NC}"
        echo -e "     • Wait until after the reset time mentioned above and re-run this script."
        echo ""
        
        read -p "🤔 Would you like to continue with a temporary Staging SSL certificate? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            setup_staging_ssl
        else
            exit 1
        fi
    else
        warning "⚠️ The SSL certificate might not be ready yet, or another error occurred."
        echo -e "${YELLOW}Please check the Caddy logs for more details:${NC}"
        $DOCKER_COMPOSE logs caddy | tail -50
    fi
}

setup_staging_ssl() {
    warning "🔧 Switching to a Staging SSL certificate..."
    
    $DOCKER_COMPOSE down
    
    docker volume rm ${INSTALL_DIR##*/}_caddy_data ${INSTALL_DIR##*/}_caddy_config 2>/dev/null || true
    
    sed -i '/acme_ca/c\    acme_ca https://acme-staging-v02.api.letsencrypt.org/directory' "$INSTALL_DIR/Caddyfile"
    
    $DOCKER_COMPOSE up -d
    
    success "✅ Switched to a Staging SSL certificate."
    warning "⚠️ Your browser will show a 'Not Secure' warning. This is normal for a staging certificate."
}

# =============================================================================
# HEALTH MONITORING SCRIPT (NEW)
# =============================================================================

create_health_monitor() {
    log "🏥 Creating health monitoring script..."
    
    cat > "$INSTALL_DIR/health-monitor.sh" << 'EOF'
#!/bin/bash

# =============================================================================
# N8N HEALTH MONITOR
# =============================================================================

LOG_FILE="/home/n8n/logs/health.log"
TIMESTAMP=$(date +"%Y-%m-%d %H:%M:%S")

mkdir -p "$(dirname "$LOG_FILE")"

# Check N8N health endpoint
N8N_HEALTH=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:5678/healthz || echo "000")

# Check container status
N8N_STATUS=$(docker inspect -f '{{.State.Status}}' n8n-container 2>/dev/null || echo "not_found")

echo "[$TIMESTAMP] N8N Health: $N8N_HEALTH, Container: $N8N_STATUS" >> "$LOG_FILE"

# Send alert if unhealthy
if [[ "$N8N_HEALTH" != "200" ]] || [[ "$N8N_STATUS" != "running" ]]; then
    if [[ -f "/home/n8n/telegram_config.txt" ]]; then
        source "/home/n8n/telegram_config.txt"
        
        if [[ -n "$TELEGRAM_BOT_TOKEN" && -n "$TELEGRAM_CHAT_ID" ]]; then
            MESSAGE="⚠️ *N8N Health Alert*
            
Time: $TIMESTAMP
Health Check HTTP Code: $N8N_HEALTH
Container Status: $N8N_STATUS

Please check your N8N instance!"
            
            curl -s -X POST "https://api.telegram.org/bot$TELEGRAM_BOT_TOKEN/sendMessage" \
                -d chat_id="$TELEGRAM_CHAT_ID" \
                -d text="$MESSAGE" \
                -d parse_mode="Markdown" > /dev/null || true
        fi
    fi
    
    # Try to restart if not running
    if [[ "$N8N_STATUS" != "running" ]]; then
        cd /home/n8n
        docker compose up -d n8n
    fi
fi
EOF

    chmod +x "$INSTALL_DIR/health-monitor.sh"
    
    success "Health monitoring script created."
}

# =============================================================================
# DEPLOYMENT
# =============================================================================

build_and_deploy() {
    log "🏗️ Building and deploying containers..."
    cd "$INSTALL_DIR"
    
    log "🛑 Stopping any old containers..."
    $DOCKER_COMPOSE down --remove-orphans 2>/dev/null || true
    
    log "🔐 Setting permissions for the data directory..."
    chown -R 1000:1000 "$INSTALL_DIR/files/"
    
    log "📦 Building Docker images..."
    $DOCKER_COMPOSE build --no-cache
    
    log "🚀 Starting services..."
    $DOCKER_COMPOSE up -d
    
    log "⏳ Waiting for services to become healthy (up to 3 minutes)..."

    local services_to_check=("n8n-container")
    if [[ "$LOCAL_MODE" != "true" ]]; then
        services_to_check+=("caddy-proxy")
    fi

    local all_healthy=false
    local max_retries=12 # 12 retries * 15 seconds = 180 seconds
    local retry_count=0

    set +e

    while [[ $retry_count -lt $max_retries ]]; do
        all_healthy=true
        for service in "${services_to_check[@]}"; do
            container_id=$(docker ps -q --filter "name=^${service}$")
            if [[ -z "$container_id" ]]; then
                warning "Service '${service}' is not running yet. Waiting... ($((retry_count+1))/${max_retries})"
                all_healthy=false
                break
            fi

            health_status=$(docker inspect --format='{{if .State.Health}}{{.State.Health.Status}}{{else}}no-health-check{{end}}' "$service")
            exit_code=$?

            if [[ $exit_code -ne 0 ]]; then
                warning "Could not check status for '${service}'. It might be restarting. Waiting... ($((retry_count+1))/${max_retries})"
                all_healthy=false
                break
            fi

            if [[ "$health_status" == "healthy" ]]; then
                info "✅ Service '${service}' is healthy."
                continue
            elif [[ "$health_status" == "unhealthy" ]]; then
                error "❌ Service '${service}' has become unhealthy. Please check the logs."
                $DOCKER_COMPOSE logs "$service" --tail=50
                set -e
                exit 1
            else
                if [[ "$health_status" == "no-health-check" ]]; then
                     container_status=$(docker inspect --format='{{.State.Status}}' "$service")
                     if [[ "$container_status" == "running" ]]; then
                        info "✅ Service '${service}' is running (no health check)."
                        continue
                     else
                        warning "⏳ Service '${service}' is in state '${container_status}'. Waiting... ($((retry_count+1))/${max_retries})"
                        all_healthy=false
                        break
                     fi
                else
                    warning "⏳ Service '${service}' is still '${health_status}'. Waiting... ($((retry_count+1))/${max_retries})"
                    all_healthy=false
                    break
                fi
            fi
        done

        if [[ "$all_healthy" == "true" ]]; then
            break
        fi

        sleep 15
        ((retry_count++))
    done

    set -e

    if [[ "$all_healthy" != "true" ]]; then
        error "❌ One or more services failed to start correctly after 3 minutes."
        echo ""
        echo -e "${YELLOW}📋 Final container status:${NC}"
        $DOCKER_COMPOSE ps
        echo ""
        echo -e "${YELLOW}📋 Container logs:${NC}"
        $DOCKER_COMPOSE logs --tail=100
        echo ""
        echo -e "${YELLOW}🔧 Please run the troubleshooting script to diagnose the issue: bash ${INSTALL_DIR}/troubleshoot.sh${NC}"
        exit 1
    fi

    success "🎉 All services started successfully!"
}

# =============================================================================
# TROUBLESHOOTING SCRIPT
# =============================================================================

create_troubleshooting_script() {
    log "🔧 Creating troubleshooting script..."
    
    cat > "$INSTALL_DIR/troubleshoot.sh" << 'EOF'
#!/bin/bash

# =============================================================================
# N8N TROUBLESHOOTING SCRIPT
# =============================================================================

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m'

echo -e "${CYAN}╔══════════════════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║${WHITE}                    🔧 N8N TROUBLESHOOTING SCRIPT                            ${CYAN}║${NC}"
echo -e "${CYAN}╚══════════════════════════════════════════════════════════════════════════════╝${NC}"
echo ""

# Check Docker Compose command
if command -v docker-compose &> /dev/null; then
    DOCKER_COMPOSE="docker-compose"
elif docker compose version &> /dev/null; then
    DOCKER_COMPOSE="docker compose"
else
    echo -e "${RED}❌ Docker Compose not found!${NC}"
    exit 1
fi

cd /home/n8n

echo -e "${BLUE}📍 1. System Information:${NC}"
echo "• OS: $(lsb_release -d | cut -f2)"
echo "• Kernel: $(uname -r)"
echo "• Docker: $(docker --version)"
echo "• Docker Compose: $($DOCKER_COMPOSE version)"
echo "• Disk Usage: $(df -h /home/n8n | tail -1 | awk '{print $5}')"
echo "• Memory: $(free -h | grep Mem | awk '{print $3"/"$2}')"
echo "• Uptime: $(uptime -p)"
echo ""

echo -e "${BLUE}📍 2. Installation Mode:${NC}"
if [[ -f "Caddyfile" ]]; then
    echo "• Mode: Production Mode (with SSL)"
    DOMAIN=$(grep -E "^[a-zA-Z0-9.-]+\s*{" Caddyfile | head -1 | awk '{print $1}')
    echo "• Domain: $DOMAIN"
else
    echo "• Mode: Local Mode"
    echo "• Access: http://localhost:5678"
fi
echo ""

echo -e "${BLUE}📍 3. Container Status:${NC}"
$DOCKER_COMPOSE ps
echo ""

echo -e "${BLUE}📍 4. Docker Images:${NC}"
docker images | grep -E "(n8n|caddy)"
echo ""

echo -e "${BLUE}📍 5. Network Status:${NC}"
echo "• Docker Networks:"
docker network ls | grep n8n
echo ""

if [[ -n "$DOMAIN" && "$DOMAIN" != "localhost" ]]; then
    echo -e "${BLUE}📍 6. SSL Certificate Status:${NC}"
    echo "• Domain: $DOMAIN"
    echo "• DNS Resolution: $(dig +short $DOMAIN A | tail -1)"
    echo "• SSL Test:"
    timeout 10 curl -I https://$DOMAIN 2>/dev/null | head -3 || echo "  SSL not ready"
    echo ""
fi

echo -e "${BLUE}📍 7. File Permissions:${NC}"
echo "• N8N data directory: $(ls -ld /home/n8n/files | awk '{print $1" "$3":"$4}')"
echo "• Database file: $(ls -l /home/n8n/files/database.sqlite 2>/dev/null | awk '{print $1" "$3":"$4}' || echo 'Not found')"
echo ""

echo -e "${BLUE}📍 8. Health Check:${NC}"
echo "• N8N Health Endpoint: $(curl -s -o /dev/null -w "%{http_code}" http://localhost:5678/healthz || echo "Failed")"
echo "• Last health check logs:"
tail -5 /home/n8n/logs/health.log 2>/dev/null || echo "  No health logs found"
echo ""

echo -e "${BLUE}📍 9. Cron Jobs:${NC}"
crontab -l 2>/dev/null | grep -E "(n8n|backup|update)" || echo "• No N8N cron jobs found"
echo ""

echo -e "${BLUE}📍 10. Recent Error Logs:${NC}"
echo -e "${YELLOW}N8N Container Errors:${NC}"
$DOCKER_COMPOSE logs n8n 2>&1 | grep -i "error" | tail -10 || echo "No errors found"
echo ""

echo -e "${BLUE}📍 11. Backup Status:${NC}"
if [[ -d "/home/n8n/files/backup_full" ]]; then
    BACKUP_COUNT=$(ls -1 /home/n8n/files/backup_full/n8n_backup_*.tar.gz 2>/dev/null | wc -l)
    echo "• Total backup files: $BACKUP_COUNT"
    if [[ $BACKUP_COUNT -gt 0 ]]; then
        echo "• Latest backup: $(ls -t /home/n8n/files/backup_full/n8n_backup_*.tar.gz | head -1 | xargs basename)"
        echo "• Latest backup size: $(ls -lh /home/n8n/files/backup_full/n8n_backup_*.tar.gz | head -1 | awk '{print $5}')"
    fi
else
    echo "• No backup directory found"
fi
echo ""

echo -e "${BLUE}📍 12. Update Status:${NC}"
if [[ -f "/home/n8n/logs/update.log" ]]; then
    echo "• Last update attempt:"
    tail -5 /home/n8n/logs/update.log
else
    echo "• No update logs found"
fi
echo ""

echo -e "${GREEN}🔧 QUICK FIX COMMANDS:${NC}"
echo -e "${YELLOW}• Fix permissions:${NC} chown -R 1000:1000 /home/n8n/files/"
echo -e "${YELLOW}• Restart all services:${NC} cd /home/n8n && $DOCKER_COMPOSE restart"
echo -e "${YELLOW}• View live logs:${NC} cd /home/n8n && $DOCKER_COMPOSE logs -f"
echo -e "${YELLOW}• Rebuild containers:${NC} cd /home/n8n && $DOCKER_COMPOSE down && $DOCKER_COMPOSE up -d --build"
echo -e "${YELLOW}• Run manual backup:${NC} /home/n8n/backup-manual.sh"
echo -e "${YELLOW}• Run manual update:${NC} /home/n8n/update-n8n.sh"
echo -e "${YELLOW}• Run health check:${NC} /home/n8n/health-monitor.sh"

if [[ -n "$DOMAIN" && "$DOMAIN" != "localhost" ]]; then
    echo -e "${YELLOW}• Check SSL:${NC} curl -I https://$DOMAIN"
fi

echo ""
echo -e "${CYAN}✅ Troubleshooting completed!${NC}"
EOF

    chmod +x "$INSTALL_DIR/troubleshoot.sh"
    
    success "Troubleshooting script created."
}

# =============================================================================
# FINAL SUMMARY
# =============================================================================

show_final_summary() {
    clear
    echo -e "${GREEN}╔══════════════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║${WHITE}                 🎉 N8N INSTALLATION COMPLETED SUCCESSFULLY!                ${GREEN}║${NC}"
    echo -e "${GREEN}╚══════════════════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    
    echo -e "${CYAN}🌐 ACCESS YOUR SERVICES:${NC}"
    if [[ "$LOCAL_MODE" == "true" ]]; then
        echo -e "  • N8N: ${WHITE}http://<your_server_ip>:5678${NC}"
    else
        echo -e "  • N8N: ${WHITE}https://${DOMAIN}${NC}"
    fi
    
    echo ""
    echo -e "${CYAN}📁 SYSTEM INFORMATION:${NC}"
    echo -e "  • Mode: ${WHITE}$([[ "$LOCAL_MODE" == "true" ]] && echo "Local Mode" || echo "Production Mode")${NC}"
    echo -e "  • Installation Directory: ${WHITE}${INSTALL_DIR}${NC}"
    echo -e "  • Troubleshooting Script: ${WHITE}${INSTALL_DIR}/troubleshoot.sh${NC}"
    echo -e "  • Manual Backup Script: ${WHITE}${INSTALL_DIR}/backup-manual.sh${NC}"
    echo -e "  • Health Monitor Script: ${WHITE}${INSTALL_DIR}/health-monitor.sh${NC}"
    echo ""
    
    echo -e "${CYAN}💾 BACKUP CONFIGURATION:${NC}"
    echo -e "  • Telegram Backup: ${WHITE}$([[ "$ENABLE_TELEGRAM" == "true" ]] && echo "Enabled" || echo "Disabled")${NC}"
    echo -e "  • Google Drive Backup: ${WHITE}$([[ "$ENABLE_GDRIVE_BACKUP" == "true" ]] && echo "Enabled" || echo "Disabled")${NC}"
    echo -e "  • Auto-Update: ${WHITE}$([[ "$ENABLE_AUTO_UPDATE" == "true" ]] && echo "Enabled (every 12 hrs)" || echo "Disabled")${NC}"
    if [[ "$LOCAL_MODE" != "true" ]]; then
        echo -e "  • Automatic Backup Schedule: ${WHITE}Daily at 2:00 AM${NC}"
        echo -e "  • Automatic Health Check: ${WHITE}Every 5 minutes${NC}"
    fi
    echo -e "  • Local Backup Location: ${WHITE}${INSTALL_DIR}/files/backup_full/${NC}"
    echo ""
    
    echo -e "${CYAN}📋 USEFUL COMMANDS:${NC}"
    echo -e "  • View live logs: ${WHITE}cd /home/n8n && $DOCKER_COMPOSE logs -f${NC}"
    echo -e "  • Restart all services: ${WHITE}cd /home/n8n && $DOCKER_COMPOSE restart${NC}"
    echo -e "  • Run a manual backup: ${WHITE}/home/n8n/backup-manual.sh${NC}"
    echo -e "  • Run a manual update: ${WHITE}/home/n8n/update-n8n.sh${NC}"
    echo -e "  • Run diagnostics: ${WHITE}/home/n8n/troubleshoot.sh${NC}"
    echo ""
    
    echo -e "${GREEN}╚══════════════════════════════════════════════════════════════════════════════╝${NC}"
}

# =============================================================================
# MAIN EXECUTION
# =============================================================================

main() {
    # Parse arguments
    parse_arguments "$@"
    
    # Show banner
    show_banner
    
    # System checks
    check_root
    check_os
    detect_environment
    check_docker_compose
    
    # Setup swap
    setup_swap
    
    # Get user input
    get_restore_option
    get_installation_mode
    get_domain_input
    get_cleanup_option
    get_backup_config
    get_auto_update_config
    
    # Verify DNS (skip for local mode)
    verify_dns
    
    # Cleanup old installation
    cleanup_old_installation
    
    # Install Docker
    install_docker
    
    # Create project structure
    create_project_structure
    
    # Perform restore if requested
    perform_restore
    create_n8n_config_file
    
    # Create configuration files
    create_dockerfile
    create_docker_compose
    create_caddyfile
    
    # Create scripts
    create_backup_scripts
    create_update_script
    create_health_monitor
    create_troubleshooting_script
    
    # Setup Backup Configs
    setup_backup_configs
    
    # Setup cron jobs (skip for local mode)
    setup_cron_jobs
    
    # Build and deploy
    build_and_deploy
    
    # Check SSL and rate limits (skip for local mode)
    check_ssl_rate_limit
    
    # Show final summary
    show_final_summary
}

# Run main function
main "$@"
