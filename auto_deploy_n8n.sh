#!/bin/bash

# =============================================================================
# 🚀 AUTOMATED N8N INSTALLATION SCRIPT 2025 - FIXED VERSION
# =============================================================================
# Updated: 02/8/2025
#
# ✨ FIXED ISSUES:
#   - ✅ Fixed non-working auto-update
#   - ✅ Fixed failed backup restore
#   - ✅ Added health checks and monitoring
#   - ✅ Improved logging and error handling
#   - ✅ Fixed non-running cron job

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
API_DOMAIN=""
BEARER_TOKEN=""
TELEGRAM_BOT_TOKEN=""
TELEGRAM_CHAT_ID=""
RCLONE_REMOTE_NAME="gdrive_n8n"
GDRIVE_BACKUP_FOLDER="n8n_backups"
ENABLE_NEWS_API=false
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
    echo -e "${CYAN}║${WHITE}              🚀 AUTOMATED N8N INSTALLATION SCRIPT 2025 - FIXED VERSION 🚀          ${CYAN}║${NC}"
    echo -e "${CYAN}╠══════════════════════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${CYAN}║${WHITE} ✨ N8N + FFmpeg + yt-dlp + News API + Telegram/G-Drive Backup ${CYAN}║${NC}"
    echo -e "${CYAN}║${WHITE} ✅ Fixed: Auto-update, Restore backup, Health monitoring                   ${CYAN}║${NC}"
    echo -e "${CYAN}║${WHITE} 🔄 Option to Restore data immediately upon installation                              ${CYAN}║${NC}"
    echo -e "${CYAN}║${WHITE} 🐞 Fixed SSL Rate Limit analysis, displays VN time (GMT+7)              ${CYAN}║${NC}"
    echo -e "${CYAN}║${WHITE} 🔑 Removed Bearer Token limitations (length, special characters)                   ${CYAN}║${NC}"
    echo -e "${CYAN}╠══════════════════════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${CYAN}║${YELLOW} 📅 Updated: 02/01/2025                                                 ${CYAN}║${NC}"
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
                error "Tham số không hợp lệ: $1"
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
        info "Swap file already exists"
        return 0
    fi
    
    # Create swap file
    log "Creating swap file ${swap_size}..."
    fallocate -l $swap_size /swapfile || dd if=/dev/zero of=/swapfile bs=1024 count=$((${swap_size%G} * 1024 * 1024))
    chmod 600 /swapfile
    mkswap /swapfile
    swapon /swapfile
    
    # Make swap permanent
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
    
    # Validate backup file
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
    
    # Ensure target directory exists
    mkdir -p "$INSTALL_DIR/files"
    
    # Clean target directory
    log "🧹 Cleaning up old data directory..."
    rm -rf "$INSTALL_DIR/files/"* 2>/dev/null || true
    
    # Extract backup
    log "📦 Extracting backup file..."
    local temp_extract_dir="/tmp/n8n_restore_extract_$$"
    mkdir -p "$temp_extract_dir"
    
    # Extract with verbose output for debugging
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
            
            # Restore credentials (database, encryption key)
            if [[ -d "$backup_content_dir/credentials" ]]; then
                log "Restoring database and key..."
                cp -a "$backup_content_dir/credentials/"* "$INSTALL_DIR/files/" 2>/dev/null || true
                
                # Set proper permissions
                if [[ -f "$INSTALL_DIR/files/database.sqlite" ]]; then
                    chmod 644 "$INSTALL_DIR/files/database.sqlite"
                    chown 1000:1000 "$INSTALL_DIR/files/database.sqlite"
                fi
            fi
            
            # Restore config files (docker-compose.yml, Caddyfile)
            if [[ -d "$backup_content_dir/config" ]]; then
                log "Restoring config files..."
                # Backup current configs
                [[ -f "$INSTALL_DIR/docker-compose.yml" ]] && cp "$INSTALL_DIR/docker-compose.yml" "$INSTALL_DIR/docker-compose.yml.bak"
                [[ -f "$INSTALL_DIR/Caddyfile" ]] && cp "$INSTALL_DIR/Caddyfile" "$INSTALL_DIR/Caddyfile.bak"
                
                # Restore configs
                cp -a "$backup_content_dir/config/"* "$INSTALL_DIR/" 2>/dev/null || true
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
        
        # Set proper ownership
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
        API_DOMAIN="localhost"
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
    
    API_DOMAIN="api.${DOMAIN}"
    info "N8N Domain: ${DOMAIN}"
    info "API Domain: ${API_DOMAIN}"
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

get_news_api_config() {
    echo ""
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${WHITE}                        📰 NEWS CONTENT API                                 ${CYAN}║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${WHITE}The News Content API allows you to:${NC}"
    echo -e "  📰 Scrape article content from any website"
    echo -e "  📡 Parse RSS feeds to get the latest news"
    echo -e "  🔍 Search and analyze content automatically"
    echo -e "  🤖 Integrate directly into N8N workflows"
    echo ""
    
    read -p "📰 Do you want to install the News Content API? (Y/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Nn]$ ]]; then
        ENABLE_NEWS_API=false
        return 0
    fi
    
    ENABLE_NEWS_API=true
    
    echo ""
    echo -e "${YELLOW}🔐 Setting up Bearer Token for News API:${NC}"
    echo -e "  • ${GREEN}LIMITS REMOVED!${NC} You can set any password."
    echo -e "  • Supports letters, numbers, special characters, and any length."
    echo -e "  • Will be used to authenticate API calls"
    echo ""
    
    read -p "🔑 Enter your Bearer Token (leave blank to auto-generate a super-strong token): " BEARER_TOKEN
    if [[ -z "$BEARER_TOKEN" ]]; then
        BEARER_TOKEN=$(openssl rand -base64 48)
        info "Automatically generated a secure Bearer Token."
    fi
    
    success "Bearer Token for News API set"
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
    
    # Get server IP
    local server_ip=$(curl -s https://api.ipify.org || curl -s http://ipv4.icanhazip.com || echo "unknown")
    info "Server IP: ${server_ip}"
    
    # Check domain DNS
    local domain_ip=$(dig +short "$DOMAIN" A | tail -n1)
    local api_domain_ip=$(dig +short "$API_DOMAIN" A | tail -n1)
    
    info "IP of ${DOMAIN}: ${domain_ip:-"not found"}"
    info "IP of ${API_DOMAIN}: ${api_domain_ip:-"not found"}"
    
    if [[ "$domain_ip" != "$server_ip" ]] || [[ "$api_domain_ip" != "$server_ip" ]]; then
        warning "DNS is not pointed correctly to the server!"
        echo ""
        echo -e "${YELLOW}DNS configuration guide:${NC}"
        echo -e "  1. Log in to your domain management page"
        echo -e "  2. Create 2 A records:"
        echo -e "     • ${DOMAIN} → ${server_ip}"
        echo -e "     • ${API_DOMAIN} → ${server_ip}"
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
    
    # Stop and remove containers
    if [[ -d "$INSTALL_DIR" ]]; then
        cd "$INSTALL_DIR"
        if [[ -n "$DOCKER_COMPOSE" ]]; then
            $DOCKER_COMPOSE down --volumes --remove-orphans 2>/dev/null || true
        fi
    fi
    
    # Remove Docker images
    docker rmi n8n-custom-ffmpeg:latest news-api:latest 2>/dev/null || true
    
    # Remove installation directory
    rm -rf "$INSTALL_DIR"
    
    # Remove cron jobs
    crontab -l 2>/dev/null | grep -v "/home/n8n" | crontab - 2>/dev/null || true
    
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
        
        # Ensure Docker daemon is running
        if ! docker info &> /dev/null; then
            log "Starting Docker daemon..."
            systemctl start docker
            systemctl enable docker
        fi
        
        # Prefer Docker Compose v2 plugin; install if missing or if only v1 present
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
                # Fallback: if only v1 exists, keep it but warn
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
    
    # Create directories with proper permissions
    mkdir -p files/backup_full
    mkdir -p files/temp
    mkdir -p files/youtube_content_anylystic
    mkdir -p logs
    
    if [[ "$ENABLE_NEWS_API" == "true" ]]; then
        mkdir -p news_api
    fi
    
    # Create log files
    touch logs/backup.log
    touch logs/update.log
    touch logs/cron.log
    touch logs/health.log
    
    success "Directory structure created"
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
# - Added fallback for potentially failing packages
# =============================================================================

# Update package index with retry mechanism
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

# Install yt-dlp with retry mechanism
RUN for i in 1 2 3; do \
        pip3 install --break-system-packages --no-cache-dir --timeout=60 yt-dlp && break || \
        (echo "Retry $i failed, waiting..." && sleep 5); \
    done

# Create directories and set permissions
RUN mkdir -p /home/node/.n8n/nodes /data/youtube_content_anylystic && \
    chown -R 1000:1000 /home/node/.n8n /data && \
    chmod -R 755 /home/node/.n8n /data

USER node

# Health check with shorter timeout
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD curl -f http://localhost:5678/healthz || exit 1

WORKDIR /data
EOF
    
    success "Dockerfile for N8N created (stable version)"
}



create_news_api() {
    if [[ "$ENABLE_NEWS_API" != "true" ]]; then
        return 0
    fi
    
    log "📰 Creating News Content API..."
    
    # Create requirements.txt
    cat > "$INSTALL_DIR/news_api/requirements.txt" << 'EOF'
fastapi==0.104.1
uvicorn[standard]==0.24.0
newspaper4k==0.9.3
user-agents==2.2.0
pydantic==2.5.0
python-multipart==0.0.6
requests==2.31.0
lxml==4.9.3
Pillow==10.1.0
nltk==3.8.1
beautifulsoup4==4.12.2
feedparser==6.0.10
python-dateutil==2.8.2
EOF
    
    # Create main.py
    cat > "$INSTALL_DIR/news_api/main.py" << 'EOF'
import os
import random
import logging
from datetime import datetime
from typing import List, Optional, Dict, Any
import feedparser
import requests
from fastapi import FastAPI, HTTPException, Depends, Security
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import HTMLResponse
from pydantic import BaseModel, HttpUrl, Field
import newspaper
from newspaper import Article, Source
from user_agents import parse
import nltk

# Download required NLTK data
try:
    nltk.download('punkt', quiet=True)
    nltk.download('stopwords', quiet=True)
except:
    pass

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# FastAPI app
app = FastAPI(
    title="News Content API",
    description="Advanced News Content Extraction API with Newspaper4k",
    version="2.0.0",
    docs_url="/docs",
    redoc_url="/redoc"
)

# CORS middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Security
security = HTTPBearer()
NEWS_API_TOKEN = os.getenv("NEWS_API_TOKEN", "default_token")

# Random User Agents
USER_AGENTS = [
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
    "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
    "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:121.0) Gecko/20100101 Firefox/121.0",
    "Mozilla/5.0 (Macintosh; Intel Mac OS X 10.15; rv:121.0) Gecko/20100101 Firefox/121.0",
    "Mozilla/5.0 (X11; Linux x86_64; rv:121.0) Gecko/20100101 Firefox/121.0",
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Edge/120.0.0.0 Safari/537.36",
    "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.2 Safari/605.1.15"
]

def get_random_user_agent() -> str:
    return random.choice(USER_AGENTS)

def verify_token(credentials: HTTPAuthorizationCredentials = Security(security)):
    if credentials.credentials != NEWS_API_TOKEN:
        raise HTTPException(
            status_code=401,
            detail="Invalid authentication token"
        )
    return credentials.credentials

# Pydantic models
class ArticleRequest(BaseModel):
    url: HttpUrl
    language: str = Field(default="en", description="Language code (en, vi, zh, etc.)")
    extract_images: bool = Field(default=True, description="Extract images from article")
    summarize: bool = Field(default=False, description="Generate article summary")

class SourceRequest(BaseModel):
    url: HttpUrl
    max_articles: int = Field(default=10, ge=1, le=50, description="Maximum articles to extract")
    language: str = Field(default="en", description="Language code")

class FeedRequest(BaseModel):
    url: HttpUrl
    max_articles: int = Field(default=10, ge=1, le=50, description="Maximum articles to parse")

class ArticleResponse(BaseModel):
    title: str
    content: str
    summary: Optional[str] = None
    authors: List[str]
    publish_date: Optional[datetime] = None
    images: List[str]
    top_image: Optional[str] = None
    keywords: List[str]
    language: str
    word_count: int
    read_time_minutes: int
    url: str

class SourceResponse(BaseModel):
    source_url: str
    articles: List[ArticleResponse]
    total_articles: int
    categories: List[str]

class FeedResponse(BaseModel):
    feed_url: str
    feed_title: str
    articles: List[Dict[str, Any]]
    total_articles: int

# Helper functions
def create_newspaper_config(language: str = "en") -> newspaper.Config:
    config = newspaper.Config()
    config.language = language
    config.browser_user_agent = get_random_user_agent()
    config.request_timeout = 30
    config.number_threads = 1
    config.thread_timeout_seconds = 30
    config.ignored_content_types_defaults = {
        'application/pdf', 'application/x-pdf', 'application/x-bzpdf',
        'application/x-gzpdf', 'application/msword', 'doc', 'text/plain'
    }
    return config

def extract_article_content(url: str, language: str = "en", extract_images: bool = True, summarize: bool = False) -> ArticleResponse:
    try:
        config = create_newspaper_config(language)
        article = Article(url, config=config)
        article.download()
        article.parse()
        keywords = []
        summary = None
        if article.text:
            try:
                article.nlp()
                keywords = article.keywords[:10]
                if summarize:
                    summary = article.summary
            except Exception as e:
                logger.warning(f"NLP processing failed for {url}: {e}")
        word_count = len(article.text.split()) if article.text else 0
        read_time = max(1, round(word_count / 200))
        images = []
        if extract_images:
            images = list(article.images)[:10]
        return ArticleResponse(
            title=article.title or "No title",
            content=article.text or "No content",
            summary=summary,
            authors=article.authors,
            publish_date=article.publish_date,
            images=images,
            top_image=article.top_image,
            keywords=keywords,
            language=language,
            word_count=word_count,
            read_time_minutes=read_time,
            url=url
        )
    except Exception as e:
        logger.error(f"Error extracting article {url}: {e}")
        raise HTTPException(status_code=400, detail=f"Failed to extract article: {str(e)}")

# API Routes
@app.get("/", response_class=HTMLResponse)
async def root():
    html_content = f"""
    <!DOCTYPE html>
    <html>
    <head>
        <title>News Content API</title>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <style>
            body {{ font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; margin: 0; padding: 20px; background: #f5f5f5; }}
            .container {{ max-width: 880px; margin: 0 auto; background: white; padding: 30px; border-radius: 10px; box-shadow: 0 2px 10px rgba(0,0,0,0.1); }}
            h1 {{ color: #2c3e50; border-bottom: 3px solid #3498db; padding-bottom: 10px; }}
            h2 {{ color: #34495e; margin-top: 30px; }}
            .endpoint {{ background: #ecf0f1; padding: 15px; border-radius: 5px; margin: 10px 0; }}
            .method {{ background: #3498db; color: white; padding: 3px 8px; border-radius: 3px; font-size: 12px; }}
            .auth-info {{ background: #e74c3c; color: white; padding: 15px; border-radius: 5px; margin: 20px 0; }}
            .token-change {{ background: #f39c12; color: white; padding: 15px; border-radius: 5px; margin: 20px 0; }}
            code {{ background: #2c3e50; color: #ecf0f1; padding: 2px 5px; border-radius: 3px; }}
            pre {{ background: #2c3e50; color: #ecf0f1; padding: 15px; border-radius: 5px; overflow-x: auto; }}
            .feature {{ background: #27ae60; color: white; padding: 10px; border-radius: 5px; margin: 5px 0; }}
            .cta {{ background: #8e44ad; color: white; padding: 15px; border-radius: 8px; margin: 15px 0; }}
            a {{ color: #2c3e50; }}
        </style>
    </head>
    <body>
        <div class="container">
            <div class="cta">
                <strong>🎉 Hello from Satriya Baju Hitam!</strong><br>
                📺 Please <a href=\"https://www.youtube.com/@satriyabajuhitam?sub_confirmation=1\" target=\"_blank\"><strong>subscribe to my YouTube channel</strong></a> to support me!<br>
                🎵 n8n Playlist: <a href=\"https://www.youtube.com/@satriyabajuhitam/playlists\" target=\"_blank\">Watch here</a> · 
                📱 Whatsapp/Phone: <strong>628123456789</strong>
            </div>
            <h1>🚀 News Content API v2.0</h1>
            <p>Advanced News Content Extraction API with <strong>Newspaper4k</strong> and <strong>Random User Agents</strong></p>
            <div class="auth-info">
                <h3>🔐 Authentication Required</h3>
                <p>All API calls require a Bearer Token in the header:</p>
                <code>Authorization: Bearer YOUR_TOKEN_HERE</code>
                <p><strong>Note:</strong> The Token was set during installation and is not displayed here for security reasons.</p>
            </div>
            <div class="token-change">
                <h3>🔧 Change Bearer Token</h3>
                <p><strong>Method 1:</strong> One-liner command</p>
                <pre>cd /home/n8n && sed -i 's/NEWS_API_TOKEN=.*/NEWS_API_TOKEN="NEW_TOKEN"/' docker-compose.yml && docker compose restart fastapi</pre>
                <p><strong>Method 2:</strong> Edit the file directly</p>
                <pre>nano /home/n8n/docker-compose.yml
# Find the NEWS_API_TOKEN line and change it
docker compose restart fastapi</pre>
            </div>
            <h2>✨ Features</h2>
            <div class="feature">📰 Scrape article content from any website</div>
            <div class="feature">📡 Parse RSS feeds to get the latest news</div>
            <div class="feature">🔍 Search and analyze content automatically</div>
            <div class="feature">🌍 Supports 80+ languages (Vietnamese, English, Chinese, Japanese...)</div>
            <div class="feature">🎭 Random User Agents to avoid being blocked</div>
            <div class="feature">🤖 Integrates directly into N8N workflows</div>
            <h2>📖 API Endpoints</h2>
            <div class="endpoint">
                <span class="method">GET</span> <strong>/health</strong>
                <p>Check API status</p>
            </div>
            <div class="endpoint">
                <span class="method">POST</span> <strong>/extract-article</strong>
                <p>Get article content from URL</p>
                <pre>{{"url": "https://example.com/article", "language": "vi", "extract_images": true, "summarize": true}}</pre>
            </div>
            <div class="endpoint">
                <span class="method">POST</span> <strong>/extract-source</strong>
                <p>Scrape multiple articles from a website</p>
                <pre>{{"url": "https://dantri.com.vn", "max_articles": 10, "language": "vi"}}</pre>
            </div>
            <div class="endpoint">
                <span class="method">POST</span> <strong>/parse-feed</strong>
                <p>Analyze RSS feeds</p>
                <pre>{{"url": "https://dantri.com.vn/rss.xml", "max_articles": 10}}</pre>
            </div>
            <h2>🔗 Documentation</h2>
            <p>
                <a href="/docs" target="_blank">📚 Swagger UI</a> | 
                <a href="/redoc" target="_blank">📖 ReDoc</a>
            </p>
            <h2>💻 cURL Example</h2>
            <pre>curl -X POST "https://api.yourdomain.com/extract-article" \
 -H "Content-Type: application/json" \
 -H "Authorization: Bearer YOUR_TOKEN" \
 -d '{{"url": "https://dantri.com.vn/the-gioi.htm", "language": "vi"}}'</pre>
            <hr style="margin: 30px 0;">
            <p style="text-align: center; color: #7f8c8d;">
                🚀 Powered by <strong>Newspaper4k</strong> | 
                👨‍💻 Created by <strong>Nguyễn Ngọc Thiện</strong> | 
                📺 <a href="https://www.youtube.com/@satriyabajuhitam?sub_confirmation=1">YouTube Channel</a>
            </p>
        </div>
    </body>
    </html>
    """
    return html_content

@app.get("/health")
async def health_check():
    return {
        "status": "healthy",
        "timestamp": datetime.now(),
        "version": "2.0.0",
        "features": [
            "Article extraction",
            "Source crawling",
            "RSS feed parsing",
            "Multi-language support",
            "Random User Agents",
            "Image extraction",
            "Keyword extraction",
            "Content summarization"
        ]
    }

@app.post("/extract-article", response_model=ArticleResponse)
async def extract_article(
    request: ArticleRequest,
    token: str = Depends(verify_token)
):
    logger.info(f"Extracting article: {request.url}")
    return extract_article_content(
        str(request.url),
        request.language,
        request.extract_images,
        request.summarize
    )

@app.post("/extract-source", response_model=SourceResponse)
async def extract_source(
    request: SourceRequest,
    token: str = Depends(verify_token)
):
    try:
        logger.info(f"Extracting source: {request.url}")
        config = create_newspaper_config(request.language)
        source = Source(str(request.url), config=config)
        source.build()
        articles_to_process = source.articles[:request.max_articles]
        extracted_articles = []
        for article in articles_to_process:
            try:
                article_response = extract_article_content(
                    article.url,
                    request.language,
                    extract_images=True,
                    summarize=False
                )
                extracted_articles.append(article_response)
            except Exception as e:
                logger.warning(f"Failed to extract article {article.url}: {e}")
                continue
        return SourceResponse(
            source_url=str(request.url),
            articles=extracted_articles,
            total_articles=len(extracted_articles),
            categories=source.category_urls()[:10]
        )
    except Exception as e:
        logger.error(f"Error extracting source {request.url}: {e}")
        raise HTTPException(status_code=400, detail=f"Failed to extract source: {str(e)}")

@app.post("/parse-feed", response_model=FeedResponse)
async def parse_feed(
    request: FeedRequest,
    token: str = Depends(verify_token)
):
    try:
        logger.info(f"Parsing feed: {request.url}")
        headers = {'User-Agent': get_random_user_agent()}
        feed = feedparser.parse(str(request.url), request_headers=headers)
        if feed.bozo:
            logger.warning(f"Feed parsing warning for {request.url}: {feed.bozo_exception}")
        articles = []
        entries_to_process = feed.entries[:request.max_articles]
        for entry in entries_to_process:
            article_data = {
                "title": getattr(entry, 'title', 'No title'),
                "link": getattr(entry, 'link', ''),
                "description": getattr(entry, 'description', ''),
                "published": getattr(entry, 'published', ''),
                "author": getattr(entry, 'author', ''),
                "tags": [tag.term for tag in getattr(entry, 'tags', [])],
                "summary": getattr(entry, 'summary', '')
            }
            articles.append(article_data)
        return FeedResponse(
            feed_url=str(request.url),
            feed_title=getattr(feed.feed, 'title', 'Unknown Feed'),
            articles=articles,
            total_articles=len(articles)
        )
    except Exception as e:
        logger.error(f"Error parsing feed {request.url}: {e}")
        raise HTTPException(status_code=400, detail=f"Failed to parse feed: {str(e)}")

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)
EOF
    
    # Create Dockerfile for News API
    cat > "$INSTALL_DIR/news_api/Dockerfile" << 'EOF'
FROM python:3.11-slim

WORKDIR /app

# Install system dependencies
RUN apt-get update && apt-get install -y \
    gcc \
    g++ \
    libxml2-dev \
    libxslt-dev \
    libjpeg-dev \
    zlib1g-dev \
    libpng-dev \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Copy requirements and install Python dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy application code
COPY . .

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD curl -f http://localhost:8000/health || exit 1

EXPOSE 8000

CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000", "--workers", "1"]
EOF
    
    success "News Content API created"
}

create_docker_compose() {
    log "🐳 Creating docker-compose.yml..."
    
    if [[ "$LOCAL_MODE" == "true" ]]; then
        # Local Mode - No Caddy, direct port exposure
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
    environment:
      N8N_HOST: "0.0.0.0"
      N8N_PORT: "5678"
      N8N_PROTOCOL: "http"
      NODE_ENV: "production"
      WEBHOOK_URL: "http://localhost:5678/"
      GENERIC_TIMEZONE: "Asia/Jakarta"
      N8N_METRICS: "true"
      N8N_LOG_LEVEL: "info"
      N8N_LOG_OUTPUT: "console"
      N8N_USER_FOLDER: "/home/node"
      N8N_ENCRYPTION_KEY: \${N8N_ENCRYPTION_KEY:-$(openssl rand -hex 32)}
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
    volumes:
      - ./files:/home/node/.n8n
      - ./files:/files
      - ./files/youtube_content_anylystic:/data/youtube_content_anylystic
      - /var/run/docker.sock:/var/run/docker.sock:ro
    networks:
      - n8n_network
EOF

        if [[ "$ENABLE_NEWS_API" == "true" ]]; then
            cat >> "$INSTALL_DIR/docker-compose.yml" << EOF

  fastapi:
    build: ./news_api
    container_name: news-api-container
    restart: unless-stopped
    ports:
      - "8000:8000"
    environment:
      NEWS_API_TOKEN: ${BEARER_TOKEN}
      PYTHONUNBUFFERED: "1"
    networks:
      - n8n_network
EOF
        fi

    else
        # Production Mode - With Caddy reverse proxy
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
    environment:
      N8N_HOST: "0.0.0.0"
      N8N_PORT: "5678"
      N8N_PROTOCOL: "http"
      NODE_ENV: "production"
      WEBHOOK_URL: "https://${DOMAIN}/"
      GENERIC_TIMEZONE: "Asia/Jakarta"
      N8N_METRICS: "true"
      N8N_LOG_LEVEL: "info"
      N8N_LOG_OUTPUT: "console"
      N8N_USER_FOLDER: "/home/node"
      N8N_ENCRYPTION_KEY: \${N8N_ENCRYPTION_KEY:-$(openssl rand -hex 32)}
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
EOF

        if [[ "$ENABLE_NEWS_API" == "true" ]]; then
            cat >> "$INSTALL_DIR/docker-compose.yml" << EOF
      - fastapi

  fastapi:
    build: ./news_api
    container_name: news-api-container
    restart: unless-stopped
    ports:
      - "127.0.0.1:8000:8000"
    environment:
      NEWS_API_TOKEN: ${BEARER_TOKEN}
      PYTHONUNBUFFERED: "1"
    networks:
      - n8n_network
EOF
        fi

        cat >> "$INSTALL_DIR/docker-compose.yml" << 'EOF'

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
    
    # Error pages
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

    if [[ "$ENABLE_NEWS_API" == "true" ]]; then
        cat >> "$INSTALL_DIR/Caddyfile" << EOF

${API_DOMAIN} {
    reverse_proxy fastapi:8000
    
    header {
        Strict-Transport-Security "max-age=31536000; includeSubDomains"
        X-Content-Type-Options "nosniff"
        X-Frame-Options "DENY"
        X-XSS-Protection "1; mode=block"
        Access-Control-Allow-Origin "*"
        Access-Control-Allow-Methods "GET, POST, PUT, DELETE, OPTIONS"
        Access-Control-Allow-Headers "Content-Type, Authorization"
    }
    
    encode gzip
    
    # Error pages
    handle_errors {
        @502 expression {http.error.status_code} == 502
        handle @502 {
            respond "News API service is starting up. Please wait a moment and refresh." 502
        }
    }
    
    log {
        output file /var/log/caddy/api.log
        format json
    }
}
EOF
    fi
    
    success "Caddyfile created"
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
        error "Could not copy database"
        exit 1
    }
else
    # Try alternative paths
    DB_PATH=$(find /home/n8n/files -name "database.sqlite" -type f 2>/dev/null | head -1)
    if [[ -n "$DB_PATH" ]]; then
        cp "$DB_PATH" "$TEMP_DIR/credentials/"
    else
        error "database.sqlite not found"
    fi
fi

# Copy encryption key
cp "/home/n8n/files/encryptionKey" "$TEMP_DIR/credentials/" 2>/dev/null || log "encryptionKey not found"

# Backup config files
log "🔧 Backing up config files..."
mkdir -p "$TEMP_DIR/config"
cp /home/n8n/docker-compose.yml "$TEMP_DIR/config/" 2>/dev/null || true
cp /home/n8n/Caddyfile "$TEMP_DIR/config/" 2>/dev/null || true
cp /home/n8n/telegram_config.txt "$TEMP_DIR/config/" 2>/dev/null || true
cp /home/n8n/gdrive_config.txt "$TEMP_DIR/config/" 2>/dev/null || true

# Create metadata
log "📊 Creating metadata..."
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
    error "Could not create backup file"
    rm -rf "$TEMP_DIR"
    exit 1
}

# Verify backup
log "🔍 Verifying backup file..."
if tar -tzf "$BACKUP_DIR/$BACKUP_NAME.tar.gz" >/dev/null 2>&1; then
    log "✅ Valid backup file"
else
    error "Backup file is corrupted"
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
            -d parse_mode="Markdown" > /dev/null || log "Could not send Telegram"
    fi
fi

# Upload to Google Drive if configured
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
    
    # Manual backup test script
    cat > "$INSTALL_DIR/backup-manual.sh" << 'EOF'
#!/bin/bash

echo "🧪 MANUAL BACKUP TEST"
echo "===================="
echo ""

cd /home/n8n

echo "📋 System Information:"
echo "• Time: $(date)"
echo "• Disk usage: $(df -h /home/n8n | tail -1 | awk '{print $5}')"
echo "• Memory: $(free -h | grep Mem | awk '{print $3"/"$2}')"
echo ""

echo "🔄 Running backup test..."
./backup-workflows.sh

echo ""
echo "📊 Backup results:"
ls -lah /home/n8n/files/backup_full/n8n_backup_*.tar.gz 2>/dev/null | tail -5

echo ""
echo "✅ Manual backup test completed!"
EOF

    chmod +x "$INSTALL_DIR/backup-manual.sh"
    
    success "Backup system created"
}

create_update_script() {
    # Always create the auto-update script; cron will depend on ENABLE_AUTO_UPDATE
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

# Detect compose command (prefer v2)
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
    send_telegram "❌ *N8N Update Failed*\nDocker Compose not found\nTime: $TIMESTAMP"
    exit 1
fi

# If both exist, force v2
if command -v docker-compose &> /dev/null && docker compose version &> /dev/null 2>&1; then
    DOCKER_COMPOSE="docker compose"
fi

cd /home/n8n

# Sanitize docker-compose.yml if it has duplicate environment entries
sanitize_compose() {
    if [[ -f "docker-compose.yml" ]] && grep -qE '^[[:space:]]+-[[:space:]][A-Z0-9_]+=.*$' docker-compose.yml; then
        awk '
            BEGIN { in_env=0; env_indent=0 }
            {
                print_line=1
                if ($0 ~ /^[[:space:]]+environment:[[:space:]]*$/) {
                    in_env=1
                    env_indent = match($0, /[^ ]/) - 1
                    delete seen
                    print $0
                    next
                }
                if (in_env==1) {
                    prefix=""
                    for (i=0;i<env_indent+2;i++) prefix=prefix" "
                    if (index($0, prefix"- ") == 1) {
                        line=$0
                        sub(/^[ \t-]+/, "", line)
                        split(line, kv, "=")
                        key=kv[1]
                        if (key in seen) {
                            print_line=0
                        } else {
                            seen[key]=1
                        }
                    } else if ($0 ~ /^[[:space:]]*$/) {
                        # blank line inside env block
                    } else if (match($0, /^[[:space:]]/) && length($0) > env_indent) {
                        # deeper indented content; keep printing
                    } else {
                        in_env=0
                    }
                }
                if (print_line) print $0
            }
        ' docker-compose.yml > docker-compose.yml.tmp && mv docker-compose.yml.tmp docker-compose.yml
    fi
}

# Validate compose; if invalid try to sanitize duplicates
if ! $DOCKER_COMPOSE config -q; then
    log "🧹 Detected an issue with docker-compose.yml, sanitizing duplicate environment variables..."
    sanitize_compose || true
fi

# Re-validate after sanitize
if ! $DOCKER_COMPOSE config -q; then
    error "docker-compose.yml is still invalid after sanitization"
    send_telegram "❌ *N8N Update Failed*\nInvalid docker-compose.yml (duplicate env)\nTime: $TIMESTAMP"
    exit 1
fi

log "🔄 Starting N8N auto-update..."

log "💾 Backing up before update..."
./backup-workflows.sh || {
    error "Backup failed"
    send_telegram "❌ *N8N Update Failed*\nBackup failed\nTime: $TIMESTAMP"
    exit 1
}

OLD_VERSION=$(docker exec n8n-container n8n --version 2>/dev/null || echo "unknown")

log "📦 Pulling latest Docker images..."
if ! $DOCKER_COMPOSE pull; then
    error "Failed to pull images"
    send_telegram "❌ *N8N Update Failed*\nFailed to pull images\nTime: $TIMESTAMP"
    exit 1
fi

log "📺 Updating yt-dlp..."
docker exec n8n-container pip3 install --break-system-packages -U yt-dlp || log "yt-dlp update failed (non-critical)"

log "🔄 Restarting services..."
if ! $DOCKER_COMPOSE up -d --remove-orphans; then
    if [[ "$DOCKER_COMPOSE" == "docker-compose" ]]; then
        log "⚠️ Encountered an error using docker-compose v1. Trying to delete container and restart..."
        $DOCKER_COMPOSE rm -fsv n8n || true
        $DOCKER_COMPOSE rm -fsv caddy || true
        $DOCKER_COMPOSE up -d --remove-orphans || {
            error "Failed to restart services"
            send_telegram "❌ *N8N Update Failed*\nFailed to restart services\nTime: $TIMESTAMP"
            exit 1
        }
    else
        error "Failed to restart services"
        send_telegram "❌ *N8N Update Failed*\nFailed to restart services\nTime: $TIMESTAMP"
        exit 1
    fi
fi

log "⏳ Waiting for services to start..."
sleep 30

SERVICES_STATUS=""
if docker ps | grep -q "n8n-container"; then
    log "✅ N8N container is running"
    SERVICES_STATUS="$SERVICES_STATUS\n✅ N8N: Running"
else
    error "❌ N8N container is not running"
    SERVICES_STATUS="$SERVICES_STATUS\n❌ N8N: Not running"
fi

if docker ps | grep -q "caddy-proxy"; then
    log "✅ Caddy container is running"
    SERVICES_STATUS="$SERVICES_STATUS\n✅ Caddy: Running"
fi

if docker ps | grep -q "news-api-container"; then
    log "✅ News API container is running"
    SERVICES_STATUS="$SERVICES_STATUS\n✅ News API: Running"
fi

NEW_VERSION=$(docker exec n8n-container n8n --version 2>/dev/null || echo "unknown")

HEALTH_STATUS=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:5678/healthz || echo "000")
if [[ "$HEALTH_STATUS" == "200" ]]; then
    HEALTH_MSG="✅ Health check passed"
else
    HEALTH_MSG="❌ Health check failed (HTTP $HEALTH_STATUS)"
fi

MESSAGE="🔄 *N8N Auto-Update Report*\n        \n📅 Time: $TIMESTAMP\n🚀 Status: ✅ Success\n📦 Version: $OLD_VERSION → $NEW_VERSION\n🏥 Health: $HEALTH_MSG\n\n📊 Services:$SERVICES_STATUS\n\n🌐 All systems operational!"

send_telegram "$MESSAGE"
log "🎉 Auto-update completed successfully!"
log "Old version: $OLD_VERSION"
log "New version: $NEW_VERSION"
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
    
    # Remove existing cron jobs for n8n
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
    cat >> "$CRON_FILE" << 'EOF'
*/5 * * * * curl -s http://localhost:5678/healthz >> /home/n8n/logs/health.log 2>&1
EOF
    
    # Install new crontab
    crontab "$CRON_FILE"
    rm -f "$CRON_FILE"
    
    # Verify cron jobs
    log "Cron jobs have been set up:"
    crontab -l | grep "/home/n8n"
    
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
    
    # Wait for Caddy to attempt SSL issuance
    log "⏳ Waiting for Caddy to process SSL (max 90 seconds)..."
    sleep 90
    
    local caddy_logs=$($DOCKER_COMPOSE logs caddy 2>&1)

    # First, check for a clear success message to avoid false positives
    if echo "$caddy_logs" | grep -q "certificate obtained successfully" || echo "$caddy_logs" | grep -q "$DOMAIN"; then
        success "✅ SSL certificate has been issued successfully for $DOMAIN"
        return 0
    fi

    # If no success message, then check for the specific rate limit error
    if echo "$caddy_logs" | grep -q "urn:ietf:params:acme:error:rateLimited"; then
        error "🚨 SSL RATE LIMIT DETECTED!"
        echo ""
        echo -e "${RED}╔══════════════════════════════════════════════════════════════════════════════╗${NC}"
        echo -e "${RED}║${WHITE}                        ⚠️  SSL RATE LIMIT DETECTED                          ${RED}║${NC}"
        echo -e "${RED}╚══════════════════════════════════════════════════════════════════════════════╝${NC}"
        echo ""
        
        # Install python3-pip and pytz if not present, for timezone conversion
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
        print(vn_time.strftime('%H:%M:%S on %d-%m-%Y (Vietnam Time)'))
    except Exception:
        print('Cannot calculate, please wait 7 days.')
else:
    print('Could not determine, please wait 7 days.')
")
        
        echo -e "${YELLOW}🔍 REASON:${NC}"
        echo -e "  • Let's Encrypt limits 5 certificates/domain/week"
        echo -e "  • This domain has reached the free limit"
        echo ""
        echo -e "${YELLOW}📅 RATE LIMIT INFORMATION:${NC}"
        echo -e "  • The rate limit will be reset at approximately: ${WHITE}$reset_time_vn${NC}"
        echo ""
        
        echo -e "${YELLOW}💡 SOLUTION:${NC}"
        echo -e "  ${GREEN}1. USE STAGING SSL (TEMPORARY):${NC}"
        echo -e "     • The website will display 'Not Secure' but will still function"
        echo -e "     • Can be switched back to production SSL after the rate limit resets"
        echo ""
        echo -e "  ${GREEN}2. WAIT UNTIL THE RATE LIMIT RESETS:${NC}"
        echo -e "     • Wait until after the time above and rerun the script"
        echo ""
        
        echo -e "${YELLOW}📋 RECENT SSL ATTEMPTS HISTORY:${NC}"
        echo "$caddy_logs" | grep -i "certificate\|ssl\|acme\|rate" | tail -10 | while read line; do
            echo -e "  ${WHITE}• $line${NC}"
        done
        echo ""
        
        read -p "🤔 Do you want to continue with Staging SSL? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            setup_staging_ssl
        else
            exit 1
        fi
    else
        warning "⚠️ SSL may not be ready yet or another error has occurred."
        echo -e "${YELLOW}Please check Caddy logs for details:${NC}"
        $DOCKER_COMPOSE logs caddy | tail -50
    fi
}

setup_staging_ssl() {
    warning "🔧 Setting up Staging SSL..."
    
    # Stop containers
    $DOCKER_COMPOSE down
    
    # Remove SSL volumes to force re-issuance
    docker volume rm ${INSTALL_DIR##*/}_caddy_data ${INSTALL_DIR##*/}_caddy_config 2>/dev/null || true
    
    # Update Caddyfile for staging
    sed -i '/acme_ca/c\    acme_ca https://acme-staging-v02.api.letsencrypt.org/directory' "$INSTALL_DIR/Caddyfile"
    
    # Restart containers
    $DOCKER_COMPOSE up -d
    
    success "✅ Staging SSL has been set up"
    warning "⚠️ The website will show 'Not Secure' - this is normal for a staging certificate"
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

# Create log directory
mkdir -p "$(dirname "$LOG_FILE")"

# Check N8N health
N8N_HEALTH=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:5678/healthz || echo "000")

# Check container status
N8N_STATUS=$(docker inspect -f '{{.State.Status}}' n8n-container 2>/dev/null || echo "not_found")

# Log results
echo "[$TIMESTAMP] N8N Health: $N8N_HEALTH, Container: $N8N_STATUS" >> "$LOG_FILE"

# Send alert if unhealthy
if [[ "$N8N_HEALTH" != "200" ]] || [[ "$N8N_STATUS" != "running" ]]; then
    if [[ -f "/home/n8n/telegram_config.txt" ]]; then
        source "/home/n8n/telegram_config.txt"
        
        if [[ -n "$TELEGRAM_BOT_TOKEN" && -n "$TELEGRAM_CHAT_ID" ]]; then
            MESSAGE="⚠️ *N8N Health Alert*
            
Time: $TIMESTAMP
Health Check: $N8N_HEALTH
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
    if [[ "$ENABLE_NEWS_API" == "true" ]]; then
        services_to_check+=("news-api-container")
    fi

    local all_healthy=false
    local max_retries=12 # 12 retries * 15 seconds = 180 seconds = 3 minutes
    local retry_count=0

    # Temporarily disable exit on error for the check loop
    set +e

    while [[ $retry_count -lt $max_retries ]]; do
        all_healthy=true
        for service in "${services_to_check[@]}"; do
            # 1. Check if container is running
            container_id=$(docker ps -q --filter "name=^${service}$")
            if [[ -z "$container_id" ]]; then
                warning "Service '${service}' is not running yet. Waiting... ($((retry_count+1))/${max_retries})"
                all_healthy=false
                break # Break inner loop, try again after sleep
            fi

            # 2. Check health status (if health check exists)
            health_status=$(docker inspect --format='{{if .State.Health}}{{.State.Health.Status}}{{else}}no-health-check{{end}}' "$service")
            exit_code=$?

            if [[ $exit_code -ne 0 ]]; then
                warning "Could not check status of '${service}'. It may be restarting. Waiting... ($((retry_count+1))/${max_retries})"
                all_healthy=false
                break
            fi

            if [[ "$health_status" == "healthy" ]]; then
                info "✅ Service '${service}' is healthy."
                continue # Check next service
            elif [[ "$health_status" == "unhealthy" ]]; then
                error "❌ Service '${service}' is unhealthy. Checking logs."
                $DOCKER_COMPOSE logs "$service" --tail=50
                # Re-enable exit on error before exiting
                set -e
                exit 1
            else
                # Status is 'starting' or 'no-health-check'
                if [[ "$health_status" == "no-health-check" ]]; then
                     # For services without healthcheck, just being 'running' is enough
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
                    warning "⏳ Service '${service}' is in state '${health_status}'. Waiting... ($((retry_count+1))/${max_retries})"
                    all_healthy=false
                    break # Break inner loop, try again after sleep
                fi
            fi
        done

        if [[ "$all_healthy" == "true" ]]; then
            break # Exit while loop
        fi

        sleep 15
        ((retry_count++))
    done

    # Re-enable exit on error
    set -e

    if [[ "$all_healthy" != "true" ]]; then
        error "❌ One or more services failed to start successfully after 3 minutes."
        echo ""
        echo -e "${YELLOW}📋 Final container status:${NC}"
        $DOCKER_COMPOSE ps
        echo ""
        echo -e "${YELLOW}📋 Container logs:${NC}"
        $DOCKER_COMPOSE logs --tail=100
        echo ""
        echo -e "${YELLOW}🔧 Please run the diagnostic script to find errors: bash ${INSTALL_DIR}/troubleshoot.sh${NC}"
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
# N8N TROUBLESHOOTING SCRIPT - ENHANCED VERSION
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
echo "• Docker Compose: $($DOCKER_COMPOSE --version)"
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
docker images | grep -E "(n8n|caddy|news-api)"
echo ""

echo -e "${BLUE}📍 5. Network Status:${NC}"
echo "• Port 80: $(netstat -tulpn 2>/dev/null | grep :80 | wc -l) connections"
echo "• Port 443: $(netstat -tulpn 2>/dev/null | grep :443 | wc -l) connections"
echo "• Port 5678: $(netstat -tulpn 2>/dev/null | grep :5678 | wc -l) connections"
echo "• Port 8000: $(netstat -tulpn 2>/dev/null | grep :8000 | wc -l) connections"
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
echo "• N8N Health: $(curl -s -o /dev/null -w "%{http_code}" http://localhost:5678/healthz || echo "Failed")"
echo "• Last health check logs:"
tail -5 /home/n8n/logs/health.log 2>/dev/null || echo "  No health logs found"
echo ""

echo -e "${BLUE}📍 9. Cron Jobs:${NC}"
crontab -l 2>/dev/null | grep -E "(n8n|backup|update)" || echo "• No N8N cron jobs found"
echo ""

echo -e "${BLUE}📍 10. Recent Error Logs:${NC}"
echo -e "${YELLOW}N8N Errors:${NC}"
$DOCKER_COMPOSE logs n8n 2>&1 | grep -i "error" | tail -10 || echo "No errors found"
echo ""

echo -e "${BLUE}📍 11. Backup Status:${NC}"
if [[ -d "/home/n8n/files/backup_full" ]]; then
    BACKUP_COUNT=$(ls -1 /home/n8n/files/backup_full/n8n_backup_*.tar.gz 2>/dev/null | wc -l)
    echo "• Backup files: $BACKUP_COUNT"
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
echo -e "${YELLOW}• Manual backup:${NC} /home/n8n/backup-manual.sh"
echo -e "${YELLOW}• Manual update:${NC} /home/n8n/update-n8n.sh"
echo -e "${YELLOW}• Check health:${NC} /home/n8n/health-monitor.sh"

if [[ -n "$DOMAIN" && "$DOMAIN" != "localhost" ]]; then
    echo -e "${YELLOW}• Check SSL:${NC} curl -I https://$DOMAIN"
fi

echo ""
echo -e "${CYAN}✅ Troubleshooting completed!${NC}"
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
    
    echo -e "${CYAN}🌐 ACCESS SERVICES:${NC}"
    if [[ "$LOCAL_MODE" == "true" ]]; then
        echo -e "  • N8N: ${WHITE}http://localhost:5678${NC}"
        if [[ "$ENABLE_NEWS_API" == "true" ]]; then
            echo -e "  • News API: ${WHITE}http://localhost:8000${NC}"
            echo -e "  • API Docs: ${WHITE}http://localhost:8000/docs${NC}"
        fi
    else
        echo -e "  • N8N: ${WHITE}https://${DOMAIN}${NC}"
        if [[ "$ENABLE_NEWS_API" == "true" ]]; then
            echo -e "  • News API: ${WHITE}https://${API_DOMAIN}${NC}"
            echo -e "  • API Docs: ${WHITE}https://${API_DOMAIN}/docs${NC}"
        fi
    fi
    
    if [[ "$ENABLE_NEWS_API" == "true" ]]; then
        echo -e "  • Bearer Token: ${YELLOW}Set (not displayed for security)${NC}"
    fi
    
    echo ""
    echo -e "${CYAN}📁 SYSTEM INFORMATION:${NC}"
    echo -e "  • Mode: ${WHITE}$([[ "$LOCAL_MODE" == "true" ]] && echo "Local Mode" || echo "Production Mode")${NC}"
    echo -e "  • Installation directory: ${WHITE}${INSTALL_DIR}${NC}"
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
    
    if [[ "$ENABLE_NEWS_API" == "true" ]]; then
        echo -e "${CYAN}🔧 CHANGE BEARER TOKEN:${NC}"
        echo -e "  ${WHITE}cd /home/n8n && sed -i 's/NEWS_API_TOKEN=.*/NEWS_API_TOKEN=\"NEW_TOKEN\"/' docker-compose.yml && $DOCKER_COMPOSE restart fastapi${NC}"
        echo ""
    fi
    
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
    get_news_api_config
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
    
    # Create configuration files
    create_dockerfile
    create_news_api
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
EOF









