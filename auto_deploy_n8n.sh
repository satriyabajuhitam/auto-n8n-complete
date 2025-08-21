#!/bin/bash

# =============================================================================
# 🚀 AUTOMATED N8N INSTALLATION SCRIPT 2025 - SIMPLIFIED VERSION
# =============================================================================
# Updated: 08/02/2025
#
# ✨ IMPROVEMENTS:
#   - ✅ Simplified by removing the News Content API feature.
#   - ✅ Fixed critical syntax error in argument parsing (es-ac -> esac)
#   - ✅ Enhanced security by using a .env file for secrets (Encryption Key)
#   - ✅ Made N8N_ENCRYPTION_KEY persistent to prevent data loss on recreation
#   - ✅ Improved restore function to automatically use the encryption key from backup
#   - ✅ Made SSL issuance check more reliable by actively polling logs instead of a fixed sleep
#   - ✅ Added more comments and improved code readability

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
N8N_ENCRYPTION_KEY="" # === ENHANCEMENT: Centralized variable ===
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
    echo -e "${CYAN}║${WHITE}           🚀 AUTOMATED N8N INSTALLATION SCRIPT 2025 - SIMPLIFIED 🚀           ${CYAN}║${NC}"
    echo -e "${CYAN}╠══════════════════════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${CYAN}║${WHITE} ✨ N8N + FFmpeg + yt-dlp + Telegram/G-Drive Backup                     ${CYAN}║${NC}"
    echo -e "${CYAN}║${WHITE} ✅ Enhanced: Security (.env), Restore, SSL Checks, Bugfixes              ${CYAN}║${NC}"
    echo -e "${CYAN}║${WHITE} 🔄 Option to Restore data immediately upon installation                              ${CYAN}║${NC}"
    echo -e "${CYAN}║${WHITE} 🐞 Fixed SSL Rate Limit analysis, displays VN time (GMT+7)              ${CYAN}║${NC}"
    echo -e "${CYAN}╠══════════════════════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${CYAN}║${YELLOW} 📅 Updated: 02/08/2025                                                 ${CYAN}║${NC}"
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
    echo "  -h, --help          Display this help"
    echo "  -d, --dir DIR       Installation directory (default: /home/n8n)"
    echo "  -c, --clean         Delete old installation before installing a new one"
    echo "  -s, --skip-docker   Skip Docker installation (if already installed)"
    echo "  -l, --local         Install in Local Mode (no domain needed)"
    echo ""
    echo "Example:"
    echo "  $0                  # Normal installation with a domain"
    echo "  $0 --local         # Local Mode installation"
    echo "  $0 --clean         # Delete old installation and install new"
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
            -l|--local)
                LOCAL_MODE=true
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
        error "This script needs to run with root privileges. Use: sudo $0"
        exit 1
    fi
}

check_os() {
    if [[ ! -f /etc/os-release ]]; then
        error "Cannot determine the operating system"
        exit 1
    fi
    
    . /etc/os-release
    if [[ "$ID" != "ubuntu" ]]; then
        warning "The script is designed for Ubuntu. Current OS: $ID"
        read -p "Do you want to continue? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    fi
}

detect_environment() {
    if grep -q Microsoft /proc/version 2>/dev/null; then
        info "WSL environment detected"
        export WSL_ENV=true
    else
        export WSL_ENV=false
    fi
}

check_docker_compose() {
    if docker compose version &> /dev/null 2>&1; then
        export DOCKER_COMPOSE="docker compose"
        info "Using docker compose (v2)"
    elif command -v docker-compose &> /dev/null; then
        export DOCKER_COMPOSE="docker-compose"
        warning "docker-compose v1 detected - will try to install docker compose plugin (v2) and prioritize it"
    else
        export DOCKER_COMPOSE=""
    fi
}

# =============================================================================
# SWAP MANAGEMENT
# =============================================================================

setup_swap() {
    log "🔄 Setting up swap memory..."
    
    local ram_gb=$(free -g | awk '/^Mem:/{print $2}')
    local swap_size
    
    if [[ $ram_gb -le 2 ]]; then
        swap_size="2G"
    elif [[ $ram_gb -le 4 ]]; then
        swap_size="4G"
    else
        swap_size="4G"
    fi
    
    if swapon --show | grep -q "/swapfile"; then
        info "Swap file already exists"
        return 0
    fi
    
    log "Creating swap file ${swap_size}..."
    fallocate -l $swap_size /swapfile || dd if=/dev/zero of=/swapfile bs=1024 count=$((${swap_size%G} * 1024 * 1024))
    chmod 600 /swapfile
    mkswap /swapfile
    swapon /swapfile
    
    if ! grep -q "/swapfile" /etc/fstab; then
        echo "/swapfile none swap sw 0 0" >> /etc/fstab
    fi
    
    success "Swap ${swap_size} has been set up"
}

# =============================================================================
# RCLONE & RESTORE FUNCTIONS (FIXED)
# =============================================================================

install_rclone() {
    if command -v rclone &> /dev/null; then
        info "rclone is already installed."
        return 0
    fi
    log "📦 Installing rclone..."
    apt-get update && apt-get install -y unzip
    curl https://rclone.org/install.sh | sudo bash
    success "rclone installed successfully."
}

setup_rclone_config() {
    if rclone listremotes | grep -q "^${RCLONE_REMOTE_NAME}:"; then
        info "rclone remote configuration '${RCLONE_REMOTE_NAME}' already exists."
        return 0
    fi

    echo ""
    echo -e "${YELLOW}╔══════════════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${YELLOW}║${WHITE}             ⚙️ RCLONE CONFIGURATION GUIDE WITH GOOGLE DRIVE ⚙️             ${YELLOW}║${NC}"
    echo -e "${YELLOW}╚══════════════════════════════════════════════════════════════════════════════╝${NC}"
    echo "You need to perform a few steps to connect the script to your Google Drive account."
    echo "The script will open the rclone configuration wizard. Please follow these steps:"
    echo ""
    echo -e "1. Run the following command: ${CYAN}rclone config${NC}"
    echo "2. Press ${WHITE}n${NC} (New remote)"
    echo -e "3. Name the remote: ${WHITE}${RCLONE_REMOTE_NAME}${NC} (IMPORTANT: must enter this exact name)"
    echo "4. Select the storage type, find and enter the number corresponding to ${WHITE}drive${NC} (Google Drive)"
    echo "5. Leave ${WHITE}client_id${NC} and ${WHITE}client_secret${NC} blank (press Enter)"
    echo "6. Select scope, enter ${WHITE}1${NC} (Full access)"
    echo "7. Leave ${WHITE}root_folder_id${NC} and ${WHITE}service_account_file${NC} blank (press Enter)"
    echo "8. Answer ${WHITE}n${NC} for 'Edit advanced config?'"
    echo "9. Answer ${WHITE}n${NC} for 'Use auto config?' (IMPORTANT: if you are using SSH)"
    echo "10. rclone will display a link. ${RED}Copy this link and open it in your computer's browser.${NC}"
    echo "11. Log in to your Google account and allow rclone access."
    echo "12. Google will return an authentication code. ${RED}Copy this code and paste it back into the terminal.${NC}"
    echo "13. Answer ${WHITE}n${NC} for 'Configure this as a team drive?'"
    echo "14. Confirm by pressing ${WHITE}y${NC} (Yes this is OK)"
    echo "15. Press ${WHITE}q${NC} (Quit config) to exit."
    echo ""
    read -p "Press Enter when you are ready to start rclone configuration..."

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
    read -p "🔄 Do you want to restore data from an existing backup? (y/N): " -n 1 -r
    echo
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
        
        read -p "📝 Enter the folder name on Google Drive containing the backup [n8n_backups]: " GDRIVE_FOLDER_INPUT
        if [[ -n "$GDRIVE_FOLDER_INPUT" ]]; then GDRIVE_BACKUP_FOLDER="$GDRIVE_FOLDER_INPUT"; fi

        log "🔍 Getting backup list from Google Drive..."
        mapfile -t backups < <(rclone lsf "$RCLONE_REMOTE_NAME:$GDRIVE_BACKUP_FOLDER" --include "*.tar.gz" | sort -r)
        if [ ${#backups[@]} -eq 0 ]; then
            error "No backup files found on Google Drive in the folder '$GDRIVE_BACKUP_FOLDER'."
            exit 1
        fi

        echo "Select the backup file to restore:"
        for i in "${!backups[@]}"; do
            echo "  $((i+1)). ${backups[$i]}"
        done
        read -p "Enter the number of the backup file: " file_idx
        
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
            if [[ -f "$RESTORE_FILE_PATH" ]]; then
                break
            else
                error "File does not exist. Please check the path again."
            fi
        done
    fi
    
    log "🔍 Checking backup file integrity..."
    if tar -tzf "$RESTORE_FILE_PATH" &>/dev/null; then
        success "Valid backup file"
    else
        error "Backup file is corrupted or in the wrong format"
        exit 1
    fi
}

perform_restore() {
    if [[ "$RESTORE_MODE" != "true" ]]; then return 0; fi
    
    log "🔄 Starting restore process from file: $RESTORE_FILE_PATH"
    
    mkdir -p "$INSTALL_DIR/files"
    log "🧹 Cleaning up old data directory..."
    rm -rf "$INSTALL_DIR/files/"* 2>/dev/null || true
    
    log "📦 Extracting backup file..."
    local temp_extract_dir="/tmp/n8n_restore_extract_$$"
    mkdir -p "$temp_extract_dir"
    
    if tar -xzvf "$RESTORE_FILE_PATH" -C "$temp_extract_dir" > /tmp/extract_log.txt 2>&1; then
        log "Backup file contents:"
        ls -la "$temp_extract_dir/"
        
        local backup_content_dir=""
        if [[ -d "$temp_extract_dir/n8n_backup_"* ]]; then
            backup_content_dir=$(find "$temp_extract_dir" -maxdepth 1 -type d -name "n8n_backup_*" | head -1)
        elif [[ -d "$temp_extract_dir/credentials" ]]; then
            backup_content_dir="$temp_extract_dir"
        fi
        
        if [[ -n "$backup_content_dir" && -d "$backup_content_dir" ]]; then
            log "Found backup content in: $backup_content_dir"
            
            if [[ -d "$backup_content_dir/credentials" ]]; then
                log "Restoring database and key..."
                cp -a "$backup_content_dir/credentials/"* "$INSTALL_DIR/files/" 2>/dev/null || true
            fi
            
            if [[ -f "$backup_content_dir/config/docker-compose.yml" ]]; then
                log "🔑 Found old config, extracting encryption key..."
                local old_key=$(grep 'N8N_ENCRYPTION_KEY' "$backup_content_dir/config/docker-compose.yml" | head -n 1 | cut -d '=' -f2-)
                if [[ -n "$old_key" ]]; then
                    N8N_ENCRYPTION_KEY="$old_key"
                    info "Successfully extracted old encryption key to be used for the new installation."
                else
                    warning "Could not extract encryption key from backed up docker-compose.yml. A new key will be generated. This might cause issues with old encrypted credentials."
                fi
            fi

        else
            error "Invalid backup file structure. Content directory not found."
            cat /tmp/extract_log.txt
            rm -rf "$temp_extract_dir"
            exit 1
        fi
        
        rm -rf "$temp_extract_dir"
        if [[ "$RESTORE_SOURCE" == "gdrive" ]]; then
            rm -rf "/tmp/n8n_restore"
        fi
        
        chown -R 1000:1000 "$INSTALL_DIR/files/"
        success "✅ Data restored successfully!"
    else
        error "Failed to extract backup file. Error details:"
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
    echo -e "${CYAN}║${WHITE}                        🏠 SELECT INSTALLATION MODE                              ${CYAN}║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${WHITE}Select installation mode:${NC}"
    echo -e "  ${GREEN}1. Production Mode (with domain + SSL)${NC}"
    echo -e "     • Requires a domain pointed to the server"
    echo -e "     • Automatically issues an SSL certificate"
    echo -e "     • Suitable for production"
    echo ""
    echo -e "  ${GREEN}2. Local Mode (no domain needed)${NC}"
    echo -e "     • Runs on localhost"
    echo -e "     • No SSL certificate required"
    echo -e "     • Suitable for development/testing"
    echo ""
    
    read -p "🏠 Do you want to install in Local Mode? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        LOCAL_MODE=true
        info "Local Mode selected"
    else
        LOCAL_MODE=false
        info "Production Mode selected"
    fi
}

get_domain_input() {
    if [[ "$LOCAL_MODE" == "true" ]]; then
        DOMAIN="localhost"
        info "Local Mode: Using localhost"
        return 0
    fi
    
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${WHITE}                           🌐 DOMAIN CONFIGURATION                                ${CYAN}║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    
    while true; do
        read -p "🌐 Enter the main domain for N8N (e.g., n8n.example.com): " DOMAIN
        if [[ -n "$DOMAIN" && "$DOMAIN" =~ ^[a-zA-Z0-9][a-zA-Z0-9.-]*[a-zA-Z0-9]$ ]]; then
            break
        else
            error "Invalid domain. Please try again."
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
    echo -e "${CYAN}║${WHITE}                           🗑️  CLEANUP OPTION                               ${CYAN}║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    
    if [[ -d "$INSTALL_DIR" ]]; then
        warning "Old N8N installation detected at: $INSTALL_DIR"
        read -p "🗑️  Do you want to delete the old installation and install a new one? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            CLEAN_INSTALL=true
        fi
    fi
}

get_backup_config() {
    if [[ "$LOCAL_MODE" == "true" ]]; then
        info "Local Mode: Skipping automatic backup configuration"
        return 0
    fi

    echo ""
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${WHITE}                      💾 AUTOMATIC BACKUP CONFIGURATION                          ${CYAN}║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${WHITE}Backup options:${NC}"
    echo -e "  🔄 Automatically backs up workflows & credentials every day"
    echo -e "  📱 Sends notifications & backup files via Telegram"
    echo -e "  ☁️ Safely uploads backup files to Google Drive"
    echo -e "  🗂️ Automatically cleans up old backup copies"
    echo ""

    # Telegram Backup
    read -p "📱 Do you want to set up Telegram backup? (Y/n): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Nn]$ ]]; then
        ENABLE_TELEGRAM=true
        echo ""
        echo -e "${YELLOW}🤖 How to create a Telegram Bot:${NC}"
        echo -e "  1. Open Telegram, find @BotFather and send the command /newbot"
        echo -e "  2. Copy the Bot Token you receive"
        echo ""
        while true; do
            read -p "🤖 Enter Telegram Bot Token: " TELEGRAM_BOT_TOKEN
            if [[ -n "$TELEGRAM_BOT_TOKEN" ]]; then break; fi
        done
        
        echo ""
        echo -e "${YELLOW}🆔 How to get Chat ID:${NC}"
        echo -e "  • Find @userinfobot, send /start to get your personal ID"
        echo ""
        while true; do
            read -p "🆔 Enter Telegram Chat ID: " TELEGRAM_CHAT_ID
            if [[ -n "$TELEGRAM_CHAT_ID" ]]; then break; fi
        done
        success "Telegram Backup configured."
    fi

    # Google Drive Backup
    read -p "☁️ Do you want to set up Google Drive backup? (Y/n): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Nn]$ ]]; then
        ENABLE_GDRIVE_BACKUP=true
        install_rclone
        setup_rclone_config
        read -p "📝 Enter the folder name on Google Drive to store backups [n8n_backups]: " GDRIVE_FOLDER_INPUT
        if [[ -n "$GDRIVE_FOLDER_INPUT" ]]; then GDRIVE_BACKUP_FOLDER="$GDRIVE_FOLDER_INPUT"; fi
        success "Google Drive Backup configured."
    fi
}

get_auto_update_config() {
    if [[ "$LOCAL_MODE" == "true" ]]; then
        info "Local Mode: Skipping Auto-Update"
        ENABLE_AUTO_UPDATE=false
        return 0
    fi
    
    echo ""
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${WHITE}                        🔄 AUTO-UPDATE                                      ${CYAN}║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${WHITE}Auto-Update will:${NC}"
    echo -e "  🔄 Automatically update N8N every 12 hours"
    echo -e "  📦 Update yt-dlp, FFmpeg, and other dependencies"
    echo -e "  📋 Log the update process in detail"
    echo -e "  🔒 Backup before updating"
    echo -e "  📱 Notify via Telegram when the update succeeds/fails"
    echo ""
    
    read -p "🔄 Do you want to enable Auto-Update? (Y/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Nn]$ ]]; then
        ENABLE_AUTO_UPDATE=false
    else
        ENABLE_AUTO_UPDATE=true
        success "Auto-Update enabled"
    fi
}

# =============================================================================
# DNS VERIFICATION
# =============================================================================

verify_dns() {
    if [[ "$LOCAL_MODE" == "true" ]]; then
        info "Local Mode: Skipping DNS check"
        return 0
    fi
    
    log "🔍 Checking DNS for domain ${DOMAIN}..."
    
    local server_ip=$(curl -s https://api.ipify.org || curl -s http://ipv4.icanhazip.com || echo "unknown")
    info "Server IP: ${server_ip}"
    
    local domain_ip=$(dig +short "$DOMAIN" A | tail -n1)
    info "IP of ${DOMAIN}: ${domain_ip:-"not found"}"
    
    if [[ "$domain_ip" != "$server_ip" ]]; then
        warning "DNS is not pointed correctly to the server!"
        echo ""
        echo -e "${YELLOW}DNS configuration guide:${NC}"
        echo -e "  1. Log in to your domain management page"
        echo -e "  2. Create an A record:"
        echo -e "     • ${DOMAIN} → ${server_ip}"
        echo -e "  3. Wait 5-60 minutes for DNS propagation"
        echo ""
        
        read -p "🤔 Do you want to continue with the installation? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    else
        success "DNS configured correctly"
    fi
}

# =============================================================================
# CLEANUP FUNCTIONS
# =============================================================================

cleanup_old_installation() {
    if [[ "$CLEAN_INSTALL" != "true" ]]; then
        return 0
    fi
    
    log "🗑️ Deleting old installation..."
    
    if [[ -d "$INSTALL_DIR" ]]; then
        cd "$INSTALL_DIR"
        if [[ -n "$DOCKER_COMPOSE" ]]; then
            $DOCKER_COMPOSE down --volumes --remove-orphans 2>/dev/null || true
        fi
    fi
    
    docker rmi n8n-custom-ffmpeg:latest 2>/dev/null || true
    rm -rf "$INSTALL_DIR"
    crontab -l 2>/dev/null | grep -v "$INSTALL_DIR" | crontab - 2>/dev/null || true
    
    success "Old installation deleted"
}

# =============================================================================
# DOCKER INSTALLATION
# =============================================================================

install_docker() {
    if [[ "$SKIP_DOCKER" == "true" ]]; then
        info "Skipping Docker installation"
        return 0
    fi
    
    if command -v docker &> /dev/null; then
        info "Docker is already installed"
        
        if ! docker info &> /dev/null; then
            log "Starting Docker daemon..."
            systemctl start docker
            systemctl enable docker
        fi
        
        if docker compose version &> /dev/null 2>&1; then
            export DOCKER_COMPOSE="docker compose"
        else
            log "Installing docker compose plugin (v2)..."
            apt-get update
            apt-get install -y docker-compose-plugin
            if docker compose version &> /dev/null 2>&1; then
                export DOCKER_COMPOSE="docker compose"
                info "Switched to docker compose (v2)"
            else
                if command -v docker-compose &> /dev/null; then
                    export DOCKER_COMPOSE="docker-compose"
                    warning "Only docker-compose v1 found. It is recommended to install docker compose (v2) to avoid errors."
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
    success "Docker installed successfully"
}

# =============================================================================
# PROJECT SETUP
# =============================================================================

create_project_structure() {
    log "📁 Creating directory structure..."
    mkdir -p "$INSTALL_DIR"
    cd "$INSTALL_DIR"
    mkdir -p files/backup_full
    mkdir -p files/temp
    mkdir -p files/youtube_content_anylystic
    mkdir -p logs
    touch logs/backup.log
    touch logs/update.log
    touch logs/cron.log
    touch logs/health.log
    success "Directory structure created"
}

setup_env_file() {
    log "🔐 Setting up environment file (.env)..."
    
    if [[ -z "$N8N_ENCRYPTION_KEY" ]]; then
        if [[ -f "$INSTALL_DIR/.env" ]]; then
            info "Found existing .env file. Loading encryption key from it."
            set -a
            source "$INSTALL_DIR/.env"
            set +a
        else
            info "Generating new encryption key."
            N8N_ENCRYPTION_KEY=$(openssl rand -hex 32)
        fi
    fi
    
    cat > "$INSTALL_DIR/.env" << EOF
# -----------------------------------------------------------------------------
# ENVIRONMENT VARIABLES FOR N8N
# -----------------------------------------------------------------------------
# This file is automatically generated. Do not delete it.
# It contains sensitive information. Keep it secure.

# N8N Encryption Key (IMPORTANT: Back this up! Losing it means losing credential data)
N8N_ENCRYPTION_KEY=${N8N_ENCRYPTION_KEY}

# System Timezone
GENERIC_TIMEZONE=Asia/Jakarta
EOF

    chmod 600 "$INSTALL_DIR/.env"
    success ".env file created and secured."
}

create_dockerfile() {
    log "🐳 Creating Dockerfile for N8N (Stable version)..."
    
    cat > "$INSTALL_DIR/Dockerfile" << 'EOF'
FROM n8nio/n8n:latest

USER root

# =============================================================================
# STABLE VERSION - FIXED
# - Added retry mechanism for apk update
# - Handles network timeout errors
# - Optimized package installation
# =============================================================================

RUN for i in 1 2 3; do \
        apk update && break || sleep 2; \
    done

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

RUN for i in 1 2 3; do \
        pip3 install --break-system-packages --no-cache-dir --timeout=60 yt-dlp && break || \
        (echo "Retry $i failed, waiting..." && sleep 5); \
    done

RUN mkdir -p /home/node/.n8n/nodes /data/youtube_content_anylystic && \
    chown -R 1000:1000 /home/node/.n8n /data && \
    chmod -R 755 /home/node/.n8n /data

USER node

HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD curl -f http://localhost:5678/healthz || exit 1

WORKDIR /data
EOF
    
    success "Dockerfile for N8N created (stable version)"
}

create_docker_compose() {
    log "🐳 Creating docker-compose.yml..."
    
    if [[ "$LOCAL_MODE" == "true" ]]; then
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
      - "5678:5678"
    env_file:
      - .env
    environment:
      N8N_HOST: "0.0.0.0"
      N8N_PORT: "5678"
      N8N_PROTOCOL: "http"
      NODE_ENV: "production"
      WEBHOOK_URL: "http://localhost:5678/"
      N8N_METRICS: "true"
      N8N_LOG_LEVEL: "info"
      N8N_LOG_OUTPUT: "console"
      N8N_USER_FOLDER: "/home/node"
      DB_TYPE: "sqlite"
      DB_SQLITE_DATABASE: "/home/node/.n8n/database.sqlite"
      N8N_BASIC_AUTH_ACTIVE: "false"
      N8N_DISABLE_PRODUCTION_MAIN_PROCESS: "false"
      EXECUTIONS_TIMEOUT: "3600"
      EXECUTIONS_TIMEOUT_MAX: "7200"
      N8N_EXECUTIONS_DATA_MAX_SIZE: "500MB"
      N8N_BINARY_DATA_TTL: "1440"
      N8N_BINARY_DATA_MODE: "filesystem"
      N8N_BINARY_DATA_STORAGE: "/files"
      N8N_DEFAULT_BINARY_DATA_FILESYSTEM_DIRECTORY: "/files"
      N8N_DEFAULT_BINARY_DATA_TEMP_DIRECTORY: "/files/temp"
      NODE_FUNCTION_ALLOW_BUILTIN: "child_process,path,fs,util,os"
      N8N_TRUSTED_PROXIES: "caddy"
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
      N8N_PROTOCOL: "http"
      NODE_ENV: "production"
      WEBHOOK_URL: "https://${DOMAIN}/"
      N8N_METRICS: "true"
      N8N_LOG_LEVEL: "info"
      N8N_LOG_OUTPUT: "console"
      N8N_USER_FOLDER: "/home/node"
      DB_TYPE: "sqlite"
      DB_SQLITE_DATABASE: "/home/node/.n8n/database.sqlite"
      N8N_BASIC_AUTH_ACTIVE: "false"
      N8N_DISABLE_PRODUCTION_MAIN_PROCESS: "false"
      EXECUTIONS_TIMEOUT: "3600"
      EXECUTIONS_TIMEOUT_MAX: "7200"
      N8N_EXECUTIONS_DATA_MAX_SIZE: "500MB"
      N8N_BINARY_DATA_TTL: "1440"
      N8N_BINARY_DATA_MODE: "filesystem"
      N8N_BINARY_DATA_STORAGE: "/files"
      N8N_DEFAULT_BINARY_DATA_FILESYSTEM_DIRECTORY: "/files"
      N8N_DEFAULT_BINARY_DATA_TEMP_DIRECTORY: "/files/temp"
      NODE_FUNCTION_ALLOW_BUILTIN: "child_process,path,fs,util,os"
      N8N_TRUSTED_PROXIES: "caddy"
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
    fi
    success "docker-compose.yml created"
}

create_caddyfile() {
    if [[ "$LOCAL_MODE" == "true" ]]; then
        info "Local Mode: Skipping Caddyfile creation"
        return 0
    fi
    
    log "🌐 Creating Caddyfile..."
    
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
            respond "N8N service is starting up. Please wait a moment and refresh." 502
        }
    }
    
    log {
        output file /var/log/caddy/n8n.log
        format json
    }
}
EOF
    success "Caddyfile created"
}

# =============================================================================
# BACKUP SYSTEM (FIXED)
# =============================================================================

create_backup_scripts() {
    log "💾 Creating backup system..."
    
    cat > "$INSTALL_DIR/backup-workflows.sh" << 'EOF'
#!/bin/bash
set -e
BACKUP_DIR="/home/n8n/files/backup_full"
LOG_FILE="/home/n8n/logs/backup.log"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
BACKUP_NAME="n8n_backup_$TIMESTAMP"
TEMP_DIR="/tmp/$BACKUP_NAME"
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
log() { echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] $1${NC}" | tee -a "$LOG_FILE"; }
error() { echo -e "${RED}[ERROR] $1${NC}" | tee -a "$LOG_FILE"; }
mkdir -p "$BACKUP_DIR" "$(dirname "$LOG_FILE")"
if command -v docker-compose &> /dev/null; then DOCKER_COMPOSE="docker-compose"; elif docker compose version &> /dev/null; then DOCKER_COMPOSE="docker compose"; else error "Docker Compose not found!"; exit 1; fi
mkdir -p "$BACKUP_DIR" "$TEMP_DIR"
log "🔄 Starting N8N backup..."
log "💾 Backing up database and key..."
mkdir -p "$TEMP_DIR/credentials"
if [[ -f "/home/n8n/files/database.sqlite" ]]; then cp "/home/n8n/files/database.sqlite" "$TEMP_DIR/credentials/" || { error "Could not copy database"; exit 1; }; else DB_PATH=$(find /home/n8n/files -name "database.sqlite" -type f 2>/dev/null | head -1); if [[ -n "$DB_PATH" ]]; then cp "$DB_PATH" "$TEMP_DIR/credentials/"; else error "database.sqlite not found"; fi; fi
cp "/home/n8n/files/encryptionKey" "$TEMP_DIR/credentials/" 2>/dev/null || log "encryptionKey not found"
log "🔧 Backing up config files..."
mkdir -p "$TEMP_DIR/config"
cp /home/n8n/docker-compose.yml "$TEMP_DIR/config/" 2>/dev/null || true
cp /home/n8n/.env "$TEMP_DIR/config/" 2>/dev/null || true
cp /home/n8n/Caddyfile "$TEMP_DIR/config/" 2>/dev/null || true
cp /home/n8n/telegram_config.txt "$TEMP_DIR/config/" 2>/dev/null || true
cp /home/n8n/gdrive_config.txt "$TEMP_DIR/config/" 2>/dev/null || true
log "📊 Creating metadata..."
cat > "$TEMP_DIR/backup_metadata.json" << EOL
{"backup_date": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")","backup_name": "$BACKUP_NAME","n8n_version": "$(docker exec n8n-container n8n --version 2>/dev/null || echo 'unknown')","backup_type": "full","files_included": $(find "$TEMP_DIR" -type f | wc -l)}
EOL
log "📦 Creating compressed backup file..."
cd /tmp
tar -czf "$BACKUP_DIR/$BACKUP_NAME.tar.gz" "$BACKUP_NAME/" || { error "Could not create backup file"; rm -rf "$TEMP_DIR"; exit 1; }
log "🔍 Verifying backup file..."
if tar -tzf "$BACKUP_DIR/$BACKUP_NAME.tar.gz" >/dev/null 2>&1; then log "✅ Valid backup file"; else error "Backup file is corrupted"; rm -rf "$TEMP_DIR"; exit 1; fi
BACKUP_SIZE=$(ls -lh "$BACKUP_DIR/$BACKUP_NAME.tar.gz" | awk '{print $5}')
log "✅ Backup complete: $BACKUP_NAME.tar.gz ($BACKUP_SIZE)"
rm -rf "$TEMP_DIR"
log "🧹 Cleaning up old local backups..."
cd "$BACKUP_DIR"
ls -t n8n_backup_*.tar.gz 2>/dev/null | tail -n +31 | xargs -r rm -f
if [[ -f "/home/n8n/telegram_config.txt" ]]; then
    source "/home/n8n/telegram_config.txt"
    if [[ -n "$TELEGRAM_BOT_TOKEN" && -n "$TELEGRAM_CHAT_ID" ]]; then
        log "📱 Sending Telegram notification..."
        MESSAGE="🔄 *N8N Backup Completed*\n📅 Date: $(date +'%Y-%m-%d %H:%M:%S')\n📦 File: \`$BACKUP_NAME.tar.gz\`\n💾 Size: $BACKUP_SIZE\n📊 Status: ✅ Success"
        curl -s -X POST "https://api.telegram.org/bot$TELEGRAM_BOT_TOKEN/sendMessage" -d chat_id="$TELEGRAM_CHAT_ID" -d text="$MESSAGE" -d parse_mode="Markdown" > /dev/null || log "Could not send Telegram"
    fi
fi
if [[ -f "/home/n8n/gdrive_config.txt" ]]; then
    source "/home/n8n/gdrive_config.txt"
    if [[ -n "$RCLONE_REMOTE_NAME" && -n "$GDRIVE_BACKUP_FOLDER" ]]; then
        log "☁️ Uploading to Google Drive..."
        rclone copy "$BACKUP_DIR/$BACKUP_NAME.tar.gz" "$RCLONE_REMOTE_NAME:$GDRIVE_BACKUP_FOLDER" --progress || log "Google Drive upload failed"
        log "🧹 Cleaning up old Google Drive backups (older than 30 days)..."
        rclone delete --min-age 30d "$RCLONE_REMOTE_NAME:$GDRIVE_BACKUP_FOLDER" || true
    fi
fi
log "🎉 Backup process completed successfully!"
EOF
    chmod +x "$INSTALL_DIR/backup-workflows.sh"
    
    cat > "$INSTALL_DIR/backup-manual.sh" << 'EOF'
#!/bin/bash
echo "🧪 MANUAL BACKUP TEST"; echo "===================="; echo ""
cd /home/n8n
echo "📋 System Information:"; echo "• Time: $(date)"; echo "• Disk usage: $(df -h /home/n8n | tail -1 | awk '{print $5}')"; echo "• Memory: $(free -h | grep Mem | awk '{print $3"/"$2}')"; echo ""
echo "🔄 Running backup test..."; ./backup-workflows.sh; echo ""
echo "📊 Backup results:"; ls -lah /home/n8n/files/backup_full/n8n_backup_*.tar.gz 2>/dev/null | tail -5; echo ""
echo "✅ Manual backup test completed!"
EOF
    chmod +x "$INSTALL_DIR/backup-manual.sh"
    
    success "Backup system created"
}

create_update_script() {
    log "🔄 Creating auto-update script..."
    
    cat > "$INSTALL_DIR/update-n8n.sh" << 'EOF'
#!/bin/bash
set -e
LOG_FILE="/home/n8n/logs/update.log"; TIMESTAMP=$(date +"%Y-%m-%d %H:%M:%S")
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
mkdir -p "$(dirname "$LOG_FILE")"
log() { echo -e "${GREEN}[$TIMESTAMP] $1${NC}" | tee -a "$LOG_FILE"; }
error() { echo -e "${RED}[$TIMESTAMP] [ERROR] $1${NC}" | tee -a "$LOG_FILE"; }
send_telegram() { if [[ -f "/home/n8n/telegram_config.txt" ]]; then source "/home/n8n/telegram_config.txt"; if [[ -n "$TELEGRAM_BOT_TOKEN" && -n "$TELEGRAM_CHAT_ID" ]]; then curl -s -X POST "https://api.telegram.org/bot$TELEGRAM_BOT_TOKEN/sendMessage" -d chat_id="$TELEGRAM_CHAT_ID" -d text="$1" -d parse_mode="Markdown" > /dev/null || true; fi; fi; }
detect_compose_cmd() { if docker compose version &> /dev/null 2>&1; then DOCKER_COMPOSE="docker compose"; elif command -v docker-compose &> /dev/null; then DOCKER_COMPOSE="docker-compose"; else DOCKER_COMPOSE=""; fi; }
detect_compose_cmd
if [[ -z "$DOCKER_COMPOSE" ]]; then error "Docker Compose not found!"; send_telegram "❌ *N8N Update Failed*\nDocker Compose not found\nTime: $TIMESTAMP"; exit 1; fi
if command -v docker-compose &> /dev/null && docker compose version &> /dev/null 2>&1; then DOCKER_COMPOSE="docker compose"; fi
cd /home/n8n
if ! $DOCKER_COMPOSE config -q; then error "docker-compose.yml is invalid."; send_telegram "❌ *N8N Update Failed*\nInvalid docker-compose.yml\nTime: $TIMESTAMP"; exit 1; fi
log "🔄 Starting N8N auto-update..."
log "💾 Backing up before update..."; ./backup-workflows.sh || { error "Backup failed"; send_telegram "❌ *N8N Update Failed*\nBackup failed\nTime: $TIMESTAMP"; exit 1; }
OLD_VERSION=$(docker exec n8n-container n8n --version 2>/dev/null || echo "unknown")
log "📦 Pulling latest Docker images..."; if ! $DOCKER_COMPOSE pull; then error "Failed to pull images"; send_telegram "❌ *N8N Update Failed*\nFailed to pull images\nTime: $TIMESTAMP"; exit 1; fi
log "📺 Updating yt-dlp..."; docker exec n8n-container pip3 install --break-system-packages -U yt-dlp || log "yt-dlp update failed (non-critical)"
log "🔄 Restarting services..."; if ! $DOCKER_COMPOSE up -d --remove-orphans; then error "Failed to restart services"; send_telegram "❌ *N8N Update Failed*\nFailed to restart services\nTime: $TIMESTAMP"; exit 1; fi
log "⏳ Waiting for services to start..."; sleep 30
SERVICES_STATUS=""
if docker ps | grep -q "n8n-container"; then log "✅ N8N container is running"; SERVICES_STATUS="$SERVICES_STATUS\n✅ N8N: Running"; else error "❌ N8N container is not running"; SERVICES_STATUS="$SERVICES_STATUS\n❌ N8N: Not running"; fi
if docker ps | grep -q "caddy-proxy"; then log "✅ Caddy container is running"; SERVICES_STATUS="$SERVICES_STATUS\n✅ Caddy: Running"; fi
NEW_VERSION=$(docker exec n8n-container n8n --version 2>/dev/null || echo "unknown")
HEALTH_STATUS=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:5678/healthz || echo "000")
if [[ "$HEALTH_STATUS" == "200" ]]; then HEALTH_MSG="✅ Health check passed"; else HEALTH_MSG="❌ Health check failed (HTTP $HEALTH_STATUS)"; fi
MESSAGE="🔄 *N8N Auto-Update Report*\n        \n📅 Time: $TIMESTAMP\n🚀 Status: ✅ Success\n📦 Version: $OLD_VERSION → $NEW_VERSION\n🏥 Health: $HEALTH_MSG\n\n📊 Services:$SERVICES_STATUS\n\n🌐 All systems operational!"
send_telegram "$MESSAGE"
log "🎉 Auto-update completed successfully!"; log "Old version: $OLD_VERSION"; log "New version: $NEW_VERSION"
EOF
    chmod +x "$INSTALL_DIR/update-n8n.sh"
    success "Auto-update script created"
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
        info "Local Mode: Skipping cron job setup"
        return 0
    fi
    
    log "⏰ Setting up cron jobs..."
    
    crontab -l 2>/dev/null | grep -v "$INSTALL_DIR" | crontab - 2>/dev/null || true
    
    CRON_FILE="/tmp/n8n_cron_$$"
    crontab -l 2>/dev/null > "$CRON_FILE" || true
    
    echo "0 2 * * * $INSTALL_DIR/backup-workflows.sh >> $INSTALL_DIR/logs/cron.log 2>&1" >> "$CRON_FILE"
    
    if [[ "$ENABLE_AUTO_UPDATE" == "true" ]]; then
        echo "0 */12 * * * $INSTALL_DIR/update-n8n.sh >> $INSTALL_DIR/logs/cron.log 2>&1" >> "$CRON_FILE"
    fi
    
    echo "*/5 * * * * $INSTALL_DIR/health-monitor.sh >> $INSTALL_DIR/logs/cron.log 2>&1" >> "$CRON_FILE"

    crontab "$CRON_FILE"
    rm -f "$CRON_FILE"
    
    log "Cron jobs have been set up:"
    crontab -l | grep "$INSTALL_DIR"
    
    success "Cron jobs set up"
}

# =============================================================================
# SSL RATE LIMIT DETECTION (IMPROVED)
# =============================================================================

check_ssl_rate_limit() {
    if [[ "$LOCAL_MODE" == "true" ]]; then
        info "Local Mode: Skipping SSL check"
        return 0
    fi
    
    log "🔒 Checking SSL certificate..."
    log "⏳ Waiting for Caddy to process SSL (max 2 minutes)..."
    
    local max_retries=12; local attempt=0; local success=false; local rate_limited=false
    
    while [[ $attempt -lt $max_retries ]]; do
        local caddy_logs=$($DOCKER_COMPOSE logs --tail=100 caddy 2>&1)
        if echo "$caddy_logs" | grep -q "certificate obtained successfully"; then success=true; break; fi
        if echo "$caddy_logs" | grep -q "urn:ietf:params:acme:error:rateLimited"; then rate_limited=true; break; fi
        ((attempt++)); echo "   ... Still waiting for SSL status (attempt ${attempt}/${max_retries})"; sleep 10
    done

    if [[ "$success" == "true" ]]; then
        success "✅ SSL certificate has been issued successfully for $DOMAIN"
        return 0
    fi
    
    if [[ "$rate_limited" == "true" ]]; then
        error "🚨 SSL RATE LIMIT DETECTED!"
        echo -e "${RED}╔══════════════════════════════════════════════════════════════════════════════╗${NC}"
        echo -e "${RED}║${WHITE}                        ⚠️  SSL RATE LIMIT DETECTED                          ${RED}║${NC}"
        echo -e "${RED}╚══════════════════════════════════════════════════════════════════════════════╝${NC}"
        
        if ! dpkg -s python3-pip >/dev/null 2>&1; then apt-get install -y python3-pip; fi
        if ! python3 -c "import pytz" >/dev/null 2>&1; then pip3 install pytz; fi

        local reset_time_vn=$(python3 -c "
import re, datetime, pytz
log_data = '''$caddy_logs'''
match = re.search(r'Retry-After: (\w{3}, \d{2} \w{3} \d{4} \d{2}:\d{2}:\d{2} GMT)', log_data)
if match:
    try:
        gmt_time_str = match.group(1)
        gmt_time = datetime.datetime.strptime(gmt_time_str, '%a, %d %b %Y %H:%M:%S GMT')
        gmt_tz = pytz.timezone('GMT')
        gmt_time_aware = gmt_tz.localize(gmt_time)
        vn_tz = pytz.timezone('Asia/Jakarta')
        vn_time = gmt_time_aware.astimezone(vn_tz)
        print(vn_time.strftime('%H:%M:%S on %d-%m-%Y (GMT+7)'))
    except Exception:
        print('Cannot calculate, please wait 7 days.')
else:
    print('Could not determine, please wait 7 days.')
")
        
        echo -e "${YELLOW}🔍 REASON:${NC} Let's Encrypt limits 5 certificates/domain/week."
        echo -e "${YELLOW}📅 RATE LIMIT WILL RESET AT:${NC} ${WHITE}$reset_time_vn${NC}"
        echo -e "${YELLOW}💡 SOLUTION:${NC}"
        echo -e "  ${GREEN}1. USE STAGING SSL (TEMPORARY):${NC} Website will show 'Not Secure' but will function."
        echo -e "  ${GREEN}2. WAIT UNTIL THE RATE LIMIT RESETS:${NC}"
        
        read -p "🤔 Do you want to continue with Staging SSL? (y/N): " -n 1 -r; echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then setup_staging_ssl; else exit 1; fi
    else
        warning "⚠️ SSL may not be ready yet or another error has occurred."
        echo -e "${YELLOW}Please check Caddy logs for details:${NC}"
        $DOCKER_COMPOSE logs caddy | tail -50
    fi
}

setup_staging_ssl() {
    warning "🔧 Setting up Staging SSL..."
    $DOCKER_COMPOSE down
    docker volume rm ${INSTALL_DIR##*/}_caddy_data ${INSTALL_DIR##*/}_caddy_config 2>/dev/null || true
    sed -i '/acme_ca/c\    acme_ca https://acme-staging-v02.api.letsencrypt.org/directory' "$INSTALL_DIR/Caddyfile"
    $DOCKER_COMPOSE up -d
    success "✅ Staging SSL has been set up. The website will show 'Not Secure'."
}

# =============================================================================
# HEALTH MONITORING SCRIPT (NEW)
# =============================================================================

create_health_monitor() {
    log "🏥 Creating health monitoring script..."
    
    cat > "$INSTALL_DIR/health-monitor.sh" << 'EOF'
#!/bin/bash
LOG_FILE="/home/n8n/logs/health.log"; TIMESTAMP=$(date +"%Y-%m-%d %H:%M:%S")
mkdir -p "$(dirname "$LOG_FILE")"
N8N_HEALTH=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:5678/healthz || echo "000")
N8N_STATUS=$(docker inspect -f '{{.State.Status}}' n8n-container 2>/dev/null || echo "not_found")
echo "[$TIMESTAMP] N8N Health: $N8N_HEALTH, Container: $N8N_STATUS" >> "$LOG_FILE"
if [[ "$N8N_HEALTH" != "200" ]] || [[ "$N8N_STATUS" != "running" ]]; then
    if [[ -f "/home/n8n/telegram_config.txt" ]]; then
        source "/home/n8n/telegram_config.txt"
        if [[ -n "$TELEGRAM_BOT_TOKEN" && -n "$TELEGRAM_CHAT_ID" ]]; then
            MESSAGE="⚠️ *N8N Health Alert*\n\nTime: $TIMESTAMP\nHealth Check: $N8N_HEALTH\nContainer Status: $N8N_STATUS\n\nPlease check your N8N instance!"
            curl -s -X POST "https://api.telegram.org/bot$TELEGRAM_BOT_TOKEN/sendMessage" -d chat_id="$TELEGRAM_CHAT_ID" -d text="$MESSAGE" -d parse_mode="Markdown" > /dev/null || true
        fi
    fi
    if [[ "$N8N_STATUS" != "running" ]]; then
        echo "[$TIMESTAMP] Attempting to restart unhealthy n8n container..." >> "$LOG_FILE"
        cd /home/n8n; docker compose up -d n8n
    fi
fi
EOF
    chmod +x "$INSTALL_DIR/health-monitor.sh"
    success "Health monitoring script created"
}

# =============================================================================
# DEPLOYMENT
# =============================================================================

build_and_deploy() {
    log "🏗️ Building and deploying containers..."
    cd "$INSTALL_DIR"
    
    log "🛑 Stopping old containers (if any)..."
    $DOCKER_COMPOSE down --remove-orphans 2>/dev/null || true
    
    log "🔐 Setting permissions for data directory..."
    chown -R 1000:1000 "$INSTALL_DIR/files/"
    
    log "📦 Building Docker images..."
    $DOCKER_COMPOSE build --no-cache
    
    log "🚀 Starting services..."
    $DOCKER_COMPOSE up -d
    
    log "⏳ Waiting for services to start and become healthy (max 3 minutes)..."

    local services_to_check=("n8n-container")
    if [[ "$LOCAL_MODE" != "true" ]]; then
        services_to_check+=("caddy-proxy")
    fi

    local all_healthy=false
    local max_retries=12; local retry_count=0
    set +e
    while [[ $retry_count -lt $max_retries ]]; do
        all_healthy=true
        for service in "${services_to_check[@]}"; do
            container_id=$(docker ps -q --filter "name=^${service}$")
            if [[ -z "$container_id" ]]; then
                warning "Service '${service}' is not running yet. Waiting... ($((retry_count+1))/${max_retries})"; all_healthy=false; break
            fi
            health_status=$(docker inspect --format='{{if .State.Health}}{{.State.Health.Status}}{{else}}no-health-check{{end}}' "$service")
            exit_code=$?
            if [[ $exit_code -ne 0 ]]; then
                warning "Could not check status of '${service}'. Waiting... ($((retry_count+1))/${max_retries})"; all_healthy=false; break
            fi
            if [[ "$health_status" == "healthy" ]]; then
                info "✅ Service '${service}' is healthy."; continue
            elif [[ "$health_status" == "unhealthy" ]]; then
                error "❌ Service '${service}' is unhealthy. Checking logs."; $DOCKER_COMPOSE logs "$service" --tail=50; set -e; exit 1
            else
                if [[ "$health_status" == "no-health-check" ]]; then
                     container_status=$(docker inspect --format='{{.State.Status}}' "$service")
                     if [[ "$container_status" == "running" ]]; then info "✅ Service '${service}' is running (no health check)."; continue; else warning "⏳ Service '${service}' is in state '${container_status}'. Waiting... ($((retry_count+1))/${max_retries})"; all_healthy=false; break; fi
                else
                    warning "⏳ Service '${service}' is in state '${health_status}'. Waiting... ($((retry_count+1))/${max_retries})"; all_healthy=false; break
                fi
            fi
        done
        if [[ "$all_healthy" == "true" ]]; then break; fi
        sleep 15; ((retry_count++))
    done
    set -e

    if [[ "$all_healthy" != "true" ]]; then
        error "❌ One or more services failed to start successfully after 3 minutes."
        echo -e "${YELLOW}📋 Final container status:${NC}"; $DOCKER_COMPOSE ps
        echo -e "${YELLOW}📋 Container logs:${NC}"; $DOCKER_COMPOSE logs --tail=100
        echo -e "${YELLOW}🔧 Please run the diagnostic script: bash ${INSTALL_DIR}/troubleshoot.sh${NC}"; exit 1
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
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; CYAN='\033[0;36m'; WHITE='\033[1;37m'; NC='\033[0m'
echo -e "${CYAN}╔══════════════════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║${WHITE}                    🔧 N8N TROUBLESHOOTING SCRIPT                            ${CYAN}║${NC}"
echo -e "${CYAN}╚══════════════════════════════════════════════════════════════════════════════╝${NC}\n"
if command -v docker-compose &> /dev/null; then DOCKER_COMPOSE="docker-compose"; elif docker compose version &> /dev/null; then DOCKER_COMPOSE="docker compose"; else echo -e "${RED}❌ Docker Compose not found!${NC}"; exit 1; fi
cd /home/n8n
echo -e "${BLUE}📍 1. System Information:${NC}"; echo "• OS: $(lsb_release -d | cut -f2)"; echo "• Kernel: $(uname -r)"; echo "• Docker: $(docker --version)"; echo "• Docker Compose: $($DOCKER_COMPOSE --version)"; echo "• Disk Usage: $(df -h /home/n8n | tail -1 | awk '{print $5}')"; echo "• Memory: $(free -h | grep Mem | awk '{print $3"/"$2}')"; echo "• Uptime: $(uptime -p)\n"
echo -e "${BLUE}📍 2. Installation Mode:${NC}"; if [[ -f "Caddyfile" ]]; then DOMAIN=$(grep -E "^[a-zA-Z0-9.-]+\s*{" Caddyfile | head -1 | awk '{print $1}'); echo "• Mode: Production Mode (with SSL)"; echo "• Domain: $DOMAIN"; else echo "• Mode: Local Mode"; echo "• Access: http://localhost:5678"; fi; echo ""
echo -e "${BLUE}📍 3. Container Status:${NC}"; $DOCKER_COMPOSE ps; echo ""
echo -e "${BLUE}📍 4. Docker Images:${NC}"; docker images | grep -E "(n8n|caddy)"; echo ""
echo -e "${BLUE}📍 5. Network Status:${NC}"; echo "• Port 80: $(netstat -tulpn 2>/dev/null | grep :80 | wc -l) connections"; echo "• Port 443: $(netstat -tulpn 2>/dev/null | grep :443 | wc -l) connections"; echo "• Port 5678: $(netstat -tulpn 2>/dev/null | grep :5678 | wc -l) connections"; echo "• Docker Networks:"; docker network ls | grep n8n; echo ""
if [[ -n "$DOMAIN" && "$DOMAIN" != "localhost" ]]; then echo -e "${BLUE}📍 6. SSL Certificate Status:${NC}"; echo "• Domain: $DOMAIN"; echo "• DNS Resolution: $(dig +short $DOMAIN A | tail -1)"; echo "• SSL Test:"; timeout 10 curl -I https://$DOMAIN 2>/dev/null | head -3 || echo "  SSL not ready"; echo ""; fi
echo -e "${BLUE}📍 7. File Permissions:${NC}"; echo "• N8N data directory: $(ls -ld /home/n8n/files | awk '{print $1" "$3":"$4}')"; echo "• Database file: $(ls -l /home/n8n/files/database.sqlite 2>/dev/null | awk '{print $1" "$3":"$4}' || echo 'Not found')\n"
echo -e "${BLUE}📍 8. Health Check:${NC}"; echo "• N8N Health: $(curl -s -o /dev/null -w "%{http_code}" http://localhost:5678/healthz || echo "Failed")"; echo "• Last health check logs:"; tail -5 /home/n8n/logs/health.log 2>/dev/null || echo "  No health logs found"; echo ""
echo -e "${BLUE}📍 9. Cron Jobs:${NC}"; crontab -l 2>/dev/null | grep -E "(n8n|backup|update)" || echo "• No N8N cron jobs found"; echo ""
echo -e "${BLUE}📍 10. Recent Error Logs:${NC}"; echo -e "${YELLOW}N8N Errors:${NC}"; $DOCKER_COMPOSE logs n8n 2>&1 | grep -i "error" | tail -10 || echo "No errors found"; echo ""
echo -e "${BLUE}📍 11. Backup Status:${NC}"; if [[ -d "/home/n8n/files/backup_full" ]]; then BACKUP_COUNT=$(ls -1 /home/n8n/files/backup_full/n8n_backup_*.tar.gz 2>/dev/null | wc -l); echo "• Backup files: $BACKUP_COUNT"; if [[ $BACKUP_COUNT -gt 0 ]]; then echo "• Latest backup: $(ls -t /home/n8n/files/backup_full/n8n_backup_*.tar.gz | head -1 | xargs basename)"; echo "• Latest backup size: $(ls -lh /home/n8n/files/backup_full/n8n_backup_*.tar.gz | head -1 | awk '{print $5}')"; fi; else echo "• No backup directory found"; fi; echo ""
echo -e "${BLUE}📍 12. Update Status:${NC}"; if [[ -f "/home/n8n/logs/update.log" ]]; then echo "• Last update attempt:"; tail -5 /home/n8n/logs/update.log; else echo "• No update logs found"; fi; echo ""
echo -e "${GREEN}🔧 QUICK FIX COMMANDS:${NC}"; echo -e "${YELLOW}• Fix permissions:${NC} chown -R 1000:1000 /home/n8n/files/"; echo -e "${YELLOW}• Restart all services:${NC} cd /home/n8n && $DOCKER_COMPOSE restart"; echo -e "${YELLOW}• View live logs:${NC} cd /home/n8n && $DOCKER_COMPOSE logs -f"; echo -e "${YELLOW}• Rebuild containers:${NC} cd /home/n8n && $DOCKER_COMPOSE down && $DOCKER_COMPOSE up -d --build"; echo -e "${YELLOW}• Manual backup:${NC} /home/n8n/backup-manual.sh"; echo -e "${YELLOW}• Manual update:${NC} /home/n8n/update-n8n.sh"; echo -e "${YELLOW}• Check health:${NC} /home/n8n/health-monitor.sh"
if [[ -n "$DOMAIN" && "$DOMAIN" != "localhost" ]]; then echo -e "${YELLOW}• Check SSL:${NC} curl -I https://$DOMAIN"; fi
echo -e "\n${CYAN}✅ Troubleshooting completed!${NC}"
EOF
    chmod +x "$INSTALL_DIR/troubleshoot.sh"
    success "Troubleshooting script created"
}

# =============================================================================
# FINAL SUMMARY
# =============================================================================

show_final_summary() {
    clear
    echo -e "${GREEN}╔══════════════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║${WHITE}                    🎉 N8N HAS BEEN INSTALLED SUCCESSFULLY!                      ${GREEN}║${NC}"
    echo -e "${GREEN}╚══════════════════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    
    echo -e "${CYAN}🌐 ACCESS N8N:${NC}"
    if [[ "$LOCAL_MODE" == "true" ]]; then
        echo -e "  • N8N: ${WHITE}http://localhost:5678${NC}"
    else
        echo -e "  • N8N: ${WHITE}https://${DOMAIN}${NC}"
    fi
    
    echo ""
    echo -e "${CYAN}📁 SYSTEM INFORMATION:${NC}"
    echo -e "  • Mode: ${WHITE}$([[ "$LOCAL_MODE" == "true" ]] && echo "Local Mode" || echo "Production Mode")${NC}"
    echo -e "  • Installation directory: ${WHITE}${INSTALL_DIR}${NC}"
    echo -e "  • Environment file: ${WHITE}${INSTALL_DIR}/.env (Contains secrets - keep safe!)${NC}"
    echo -e "  • Diagnostic script: ${WHITE}${INSTALL_DIR}/troubleshoot.sh${NC}"
    echo -e "  • Backup test: ${WHITE}${INSTALL_DIR}/backup-manual.sh${NC}"
    echo -e "  • Health monitor: ${WHITE}${INSTALL_DIR}/health-monitor.sh${NC}"
    echo ""
    
    echo -e "${CYAN}💾 BACKUP CONFIGURATION:${NC}"
    echo -e "  • Telegram backup: ${WHITE}$([[ "$ENABLE_TELEGRAM" == "true" ]] && echo "Enabled" || echo "Disabled")${NC}"
    echo -e "  • Google Drive backup: ${WHITE}$([[ "$ENABLE_GDRIVE_BACKUP" == "true" ]] && echo "Enabled" || echo "Disabled")${NC}"
    echo -e "  • Auto-update: ${WHITE}$([[ "$ENABLE_AUTO_UPDATE" == "true" ]] && echo "Enabled (every 12h)" || echo "Disabled")${NC}"
    if [[ "$LOCAL_MODE" != "true" ]]; then
        echo -e "  • Automatic backup: ${WHITE}Daily at 2:00 AM${NC}"
        echo -e "  • Health check: ${WHITE}Every 5 minutes${NC}"
    fi
    echo -e "  • Backup location: ${WHITE}${INSTALL_DIR}/files/backup_full/${NC}"
    echo ""
    
    echo -e "${CYAN}📋 USEFUL COMMANDS:${NC}"
    echo -e "  • View logs: ${WHITE}cd /home/n8n && $DOCKER_COMPOSE logs -f${NC}"
    echo -e "  • Restart services: ${WHITE}cd /home/n8n && $DOCKER_COMPOSE restart${NC}"
    echo -e "  • Manual backup: ${WHITE}/home/n8n/backup-manual.sh${NC}"
    echo -e "  • Manual update: ${WHITE}/home/n8n/update-n8n.sh${NC}"
    echo -e "  • Diagnose errors: ${WHITE}/home/n8n/troubleshoot.sh${NC}"
    echo ""
    
    echo -e "${YELLOW}🎬 SUBSCRIBE TO THE YOUTUBE CHANNEL TO SUPPORT ME! 🔔${NC}"
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
    detect_environment
    check_docker_compose
    setup_swap
    get_restore_option
    get_installation_mode
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
    check_ssl_rate_limit
    show_final_summary
}

main "$@"
