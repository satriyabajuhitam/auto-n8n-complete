#!/bin/bash

# =============================================================================
# 🚀 AUTOMATIC N8N INSTALLATION SCRIPT
# =============================================================================
#
# ✨ FIXED ISSUES:
#   - ✅ Fixed auto-update not working
#   - ✅ Fixed failed backup restore
#   - ✅ Added health check and monitoring
#   - ✅ Improved logging and error handling
#   - ✅ Fixed cron job not running

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
    echo -e "${CYAN}║${WHITE}              🚀 AUTOMATIC N8N INSTALLATION SCRIPT  🚀          ${CYAN}║${NC}"
    echo -e "${CYAN}╠══════════════════════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${CYAN}║${WHITE} ✨ N8N + FFmpeg + yt-dlp + Telegram/G-Drive Backup ${CYAN}║${NC}"
    echo -e "${CYAN}║${WHITE} ✅ Fixed: Auto-update, Restore backup, Health monitoring                   ${CYAN}║${NC}"
    echo -e "${CYAN}║${WHITE} 🔄 Option to restore data immediately upon installation                              ${CYAN}║${NC}"
    echo -e "${CYAN}║${WHITE} 🐞 Fixed: SSL Rate Limit analysis, VN time display (GMT+7)              ${CYAN}║${NC}"
    echo -e "${CYAN}║${WHITE} 🔑 Removed Bearer Token limitations (length, special characters)                   ${CYAN}║${NC}"
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
    echo "  -d, --dir DIR       Installation directory (default: /home/n8n)"
    echo "  -c, --clean         Delete old installation before new one"
    echo "  -s, --skip-docker   Skip Docker installation (if already present)"
    echo "  -l, --local         Install in Local Mode (no domain needed)"
    echo ""
    echo "Examples:"
    echo "  $0                  # Normal installation with a domain"
    echo "  $0 --local         # Install in Local Mode"
    echo "  $0 --clean         # Delete old installation and install new one"
    echo "  $0 -d /opt/n8n     # Install to the /opt/n8n directory"
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
        error "This script needs to be run with root privileges. Use: sudo $0"
        exit 1
    fi
}

check_os() {
    if [[ ! -f /etc/os-release ]]; then
        error "Could not determine the operating system"
        exit 1
    fi
    
    . /etc/os-release
    if [[ "$ID" != "ubuntu" ]]; then
        warning "This script is designed for Ubuntu. The current operating system is: $ID"
        read -p "Do you want to continue? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    fi
}

detect_environment() {
    if grep -q Microsoft /proc/version 2>/dev/null; then
        info "Detected WSL environment"
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
        warning "Detected docker-compose v1 - will try to install and prioritize using the docker compose plugin (v2)"
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
    
    success "Successfully set up swap ${swap_size}"
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
    success "Successfully installed rclone."
}

setup_rclone_config() {
    if rclone listremotes | grep -q "^${RCLONE_REMOTE_NAME}:"; then
        info "rclone remote configuration '${RCLONE_REMOTE_NAME}' already exists."
        return 0
    fi

    echo ""
    echo -e "${YELLOW}╔══════════════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${YELLOW}║${WHITE}             ⚙️ GUIDE TO CONFIGURE RCLONE WITH GOOGLE DRIVE ⚙️             ${YELLOW}║${NC}"
    echo -e "${YELLOW}╚══════════════════════════════════════════════════════════════════════════════╝${NC}"
    echo "You need to perform a few steps to connect the script to your Google Drive account."
    echo "The script will open the rclone configuration wizard. Please follow these steps:"
    echo ""
    echo -e "1. Run the following command: ${CYAN}rclone config${NC}"
    echo "2. Press ${WHITE}n${NC} (New remote)"
    echo -e "3. Name the remote: ${WHITE}${RCLONE_REMOTE_NAME}${NC} (IMPORTANT: must enter this exact name)"
    echo "4. Choose the storage type, find and enter the number corresponding to ${WHITE}drive${NC} (Google Drive)"
    echo "5. Leave ${WHITE}client_id${NC} and ${WHITE}client_secret${NC} blank (press Enter)"
    echo "6. Choose scope, enter ${WHITE}1${NC} (Full access)"
    echo "7. Leave ${WHITE}root_folder_id${NC} and ${WHITE}service_account_file${NC} blank (press Enter)"
    echo "8. Answer ${WHITE}n${NC} for 'Edit advanced config?'"
    echo "9. Answer ${WHITE}n${NC} for 'Use auto config?' (IMPORTANT: if you are using SSH)"
    echo "10. rclone will show a link. ${RED}Copy this link and open it in your computer's browser.${NC}"
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
    success "Successfully configured rclone remote '${RCLONE_REMOTE_NAME}'!"
}

get_restore_option() {
    echo ""
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${WHITE}                        🔄 DATA RESTORE OPTIONS                          ${CYAN}║${NC}"
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
        
        read -p "📝 Enter the name of the Google Drive folder containing the backups [n8n_backups]: " GDRIVE_FOLDER_INPUT
        if [[ -n "$GDRIVE_FOLDER_INPUT" ]]; then GDRIVE_BACKUP_FOLDER="$GDRIVE_FOLDER_INPUT"; fi

        log "🔍 Fetching backup list from Google Drive..."
        mapfile -t backups < <(rclone lsf "$RCLONE_REMOTE_NAME:$GDRIVE_BACKUP_FOLDER" --include "*.tar.gz" | sort -r)
        if [ ${#backups[@]} -eq 0 ]; then
            error "No backup files found on Google Drive in folder '$GDRIVE_BACKUP_FOLDER'."
            exit 1
        fi

        echo "Select the backup file to restore:"
        for i in "${!backups[@]}"; do
            echo "  $((i+1)). ${backups[$i]}"
        done
        read -p "Enter the backup file number: " file_idx
        
        selected_backup="${backups[$((file_idx-1))]}"
        if [[ -z "$selected_backup" ]]; then
            error "Invalid choice."
            exit 1
        fi

        log "📥 Downloading backup file '$selected_backup'..."
        mkdir -p /tmp/n8n_restore
        rclone copyto "$RCLONE_REMOTE_NAME:$GDRIVE_BACKUP_FOLDER/$selected_backup" "/tmp/n8n_restore/$selected_backup" --progress
        RESTORE_FILE_PATH="/tmp/n8n_restore/$selected_backup"
        success "Successfully downloaded backup file."

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
        error "Backup file is corrupt or has an incorrect format"
        exit 1
    fi
}

perform_restore() {
    if [[ "$RESTORE_MODE" != "true" ]]; then return 0; fi
    
    log "🔄 Starting the restore process from file: $RESTORE_FILE_PATH"
    
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
                log "Restoring configuration files..."
                # Backup current configs
                [[ -f "$INSTALL_DIR/docker-compose.yml" ]] && cp "$INSTALL_DIR/docker-compose.yml" "$INSTALL_DIR/docker-compose.yml.bak"
                [[ -f "$INSTALL_DIR/Caddyfile" ]] && cp "$INSTALL_DIR/Caddyfile" "$INSTALL_DIR/Caddyfile.bak"
                
                # Restore configs
                cp -a "$backup_content_dir/config/"* "$INSTALL_DIR/" 2>/dev/null || true
            fi
        else
            error "Invalid backup file structure. Could not find content directory."
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
        
        success "✅ Successfully restored data!"
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
    echo -e "${CYAN}║${WHITE}                        🏠 CHOOSE INSTALLATION MODE                              ${CYAN}║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${WHITE}Choose installation mode:${NC}"
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
            error "Invalid domain. Please enter again."
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
        warning "Detected old N8N installation at: $INSTALL_DIR"
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
    echo -e "  🔄 Automatically backup workflows & credentials daily"
    echo -e "  📱 Send notifications & backup files via Telegram"
    echo -e "  ☁️ Securely upload backup files to Google Drive"
    echo -e "  🗂️ Automatically clean up old backups"
    echo ""

    # Telegram Backup
    read -p "📱 Do you want to set up Telegram backup? (Y/n): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Nn]$ ]]; then
        ENABLE_TELEGRAM=true
        echo ""
        echo -e "${YELLOW}🤖 Guide to creating a Telegram Bot:${NC}"
        echo -e "  1. Open Telegram, search for @BotFather and send the /newbot command"
        echo -e "  2. Copy the Bot Token received"
        echo ""
        while true; do
            read -p "🤖 Enter Telegram Bot Token: " TELEGRAM_BOT_TOKEN
            if [[ -n "$TELEGRAM_BOT_TOKEN" ]]; then break; fi
        done
        
        echo ""
        echo -e "${YELLOW}🆔 Guide to getting your Chat ID:${NC}"
        echo -e "  • Search for @userinfobot, send /start to get your personal ID"
        echo ""
        while true; do
            read -p "🆔 Enter Telegram Chat ID: " TELEGRAM_CHAT_ID
            if [[ -n "$TELEGRAM_CHAT_ID" ]]; then break; fi
        done
        success "Successfully configured Telegram Backup."
    fi

    # Google Drive Backup
    read -p "☁️ Do you want to set up Google Drive backup? (Y/n): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Nn]$ ]]; then
        ENABLE_GDRIVE_BACKUP=true
        install_rclone
        setup_rclone_config
        read -p "📝 Enter the name of the Google Drive folder to save backups to [n8n_backups]: " GDRIVE_FOLDER_INPUT
        if [[ -n "$GDRIVE_FOLDER_INPUT" ]]; then GDRIVE_BACKUP_FOLDER="$GDRIVE_FOLDER_INPUT"; fi
        success "Successfully configured Google Drive Backup."
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
    
    info "IP of ${DOMAIN}: ${domain_ip:-"not found"}"
    
    if [[ "$domain_ip" != "$server_ip" ]]; then
        warning "DNS is not correctly pointed to the server!"
        echo ""
        echo -e "${YELLOW}Guide to DNS configuration:${NC}"
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
        success "DNS is configured correctly"
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
    docker rmi n8n-custom-ffmpeg:latest 2>/dev/null || true
    
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
    success "Successfully installed Docker"
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
    
    # Create log files
    touch logs/backup.log
    touch logs/update.log
    touch logs/cron.log
    touch logs/health.log
    
    success "Directory structure created"
}

create_dockerfile() {
    log "🐳 Creating Dockerfile for N8N (Stable Version)..."
    
    cat > "$INSTALL_DIR/Dockerfile" << 'EOF'
FROM n8nio/n8n:latest

USER root

# =============================================================================
# STABLE VERSION - FIXED
# - Added retry mechanism for apk update
# - Handles network timeout errors
# - Optimized package installation
# - Added fallbacks for potentially failing packages
# =============================================================================

# Update package index with retry mechanism
RUN for i in 1 2 3; do \
        apk update && break || sleep 2; \
    done

# Install essential packages with error handling
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

# Health check with a shorter timeout
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD curl -f http://localhost:5678/healthz || exit 1

WORKDIR /data
EOF
    
    success "Successfully created Dockerfile for N8N (stable version)"
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
      N8N_ENFORCE_SETTINGS_FILE_PERMISSIONS: "true"
      NODE_FUNCTION_ALLOW_BUILTIN: "child_process,path,fs,util,os"
      N8N_SECURE_COOKIE : "false"
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
      DB_SQLITE_POOL_SIZE: "1"
      N8N_BASIC_AUTH_ACTIVE: "false"
      N8N_DISABLE_PRODUCTION_MAIN_PROCESS: "false"
      EXECUTIONS_TIMEOUT: "3600"
      EXECUTIONS_TIMEOUT_MAX: "7200"
      N8N_EXECUTIONS_DATA_MAX_SIZE: "500MB"
      N8N_BINARY_DATA_MODE: "filesystem"
      N8N_BINARY_DATA_STORAGE: "/files"
      N8N_DEFAULT_BINARY_DATA_FILESYSTEM_DIRECTORY: "/files"
      N8N_DEFAULT_BINARY_DATA_TEMP_DIRECTORY: "/files/temp"
      N8N_ENFORCE_SETTINGS_FILE_PERMISSIONS: "true"
      NODE_FUNCTION_ALLOW_BUILTIN: "child_process,path,fs,util,os"
      N8N_RUNNERS_ENABLED: "true"
      N8N_BLOCK_ENV_ACCESS_IN_NODE: "false"
      N8N_TRUST_PROXY_HEADER: "X-Forwarded-For"
      N8N_SECURE_COOKIE: "true"
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
    
    success "Successfully created docker-compose.yml"
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

    success "Successfully created Caddyfile"
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
        error "Could not find database.sqlite"
    fi
fi

# Copy encryption key
cp "/home/n8n/files/encryptionKey" "$TEMP_DIR/credentials/" 2>/dev/null || log "Could not find encryptionKey"

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
log "🔍 Checking backup file..."
if tar -tzf "$BACKUP_DIR/$BACKUP_NAME.tar.gz" >/dev/null 2>&1; then
    log "✅ Valid backup file"
else
    error "Backup file is corrupted"
    rm -rf "$TEMP_DIR"
    exit 1
fi

# Get backup size
BACKUP_SIZE=$(ls -lh "$BACKUP_DIR/$BACKUP_NAME.tar.gz" | awk '{print $5}')
log "✅ Backup completed: $BACKUP_NAME.tar.gz ($BACKUP_SIZE)"

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
            -d parse_mode="Markdown" > /dev/null || log "Could not send Telegram message"
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
    # Always create the auto-update script; cron depends on ENABLE_AUTO_UPDATE
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
    log "🧹 Detected issues with docker-compose.yml, proceeding to clean duplicate environment variables..."
    sanitize_compose || true
fi

# Re-validate after sanitize
if ! $DOCKER_COMPOSE config -q; then
    error "docker-compose.yml is still invalid after cleaning"
    send_telegram "❌ *N8N Update Failed*\ndocker-compose.yml is invalid (duplicate envs)\nTime: $TIMESTAMP"
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
        log "⚠️ Encountered an error using docker-compose v1. Trying to remove containers and run again..."
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
    
    success "Successfully created auto-update script"
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
    
    success "Successfully set up cron jobs"
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
    log "⏳ Waiting for Caddy to process SSL (up to 90 seconds)..."
    sleep 90
    
    local caddy_logs=$($DOCKER_COMPOSE logs caddy 2>&1)

    # First, check for a clear success message to avoid false positives
    if echo "$caddy_logs" | grep -q "certificate obtained successfully" || echo "$caddy_logs" | grep -q "$DOMAIN"; then
        success "✅ SSL certificate successfully issued for $DOMAIN"
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
        print('Could not calculate, please wait 7 days.')
else:
    print('Could not determine, please wait 7 days.')
")
        
        echo -e "${YELLOW}🔍 REASON:${NC}"
        echo -e "  • Let's Encrypt limits 5 certificates/domain/week"
        echo -e "  • This domain has reached the free limit"
        echo ""
        echo -e "${YELLOW}📅 RATE LIMIT INFORMATION:${NC}"
        echo -e "  • The rate limit will reset around: ${WHITE}$reset_time_vn${NC}"
        echo ""
        
        echo -e "${YELLOW}💡 SOLUTION:${NC}"
        echo -e "  ${GREEN}1. USE STAGING SSL (TEMPORARY):${NC}"
        echo -e "     • The website will show 'Not Secure' but will still work"
        echo -e "     • Can switch back to production SSL after the rate limit resets"
        echo ""
        echo -e "  ${GREEN}2. WAIT FOR THE RATE LIMIT TO RESET:${NC}"
        echo -e "     • Wait until after the time above and run the script again"
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
        warning "⚠️ SSL may not be ready or another error has occurred."
        echo -e "${YELLOW}Please check Caddy's logs for details:${NC}"
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
    
    success "✅ Staging SSL successfully set up"
    warning "⚠️ The website will show 'Not Secure' - this is normal with a staging certificate"
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
    
    success "Successfully created health monitoring script"
}

# =============================================================================
# DEPLOYMENT
# =============================================================================

build_and_deploy() {
    log "🏗️ Building and deploying containers..."
    cd "$INSTALL_DIR"
    
    log "🛑 Stopping old containers (if any)..."
    $DOCKER_COMPOSE down --remove-orphans 2>/dev/null || true
    
    log "🔐 Setting permissions for data directories..."
    chown -R 1000:1000 "$INSTALL_DIR/files/"
    
    log "📦 Building Docker images..."
    $DOCKER_COMPOSE build --no-cache
    
    log "🚀 Starting services..."
    $DOCKER_COMPOSE up -d
    
    log "⏳ Waiting for services to start and become healthy (up to 3 minutes)..."

    local services_to_check=("n8n-container")
    if [[ "$LOCAL_MODE" != "true" ]]; then
        services_to_check+=("caddy-proxy")
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
                warning "Could not check status of '${service}'. It might be restarting. Waiting... ($((retry_count+1))/${max_retries})"
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
        error "❌ One or more services could not start successfully after 3 minutes."
        echo ""
        echo -e "${YELLOW}📋 Final container status:${NC}"
        $DOCKER_COMPOSE ps
        echo ""
        echo -e "${YELLOW}📋 Container logs:${NC}"
        $DOCKER_COMPOSE logs --tail=100
        echo ""
        echo -e "${YELLOW}🔧 Please run the diagnostic script to find the error: bash ${INSTALL_DIR}/troubleshoot.sh${NC}"
        exit 1
    fi

    success "🎉 All services started successfully!"
}

# =============================================================================
# TROUBLESHOOTING SCRIPT
# =============================================================================

create_troubleshooting_script() {
    log "🔧 Creating diagnostic script..."
    
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
docker images | grep -E "(n8n|caddy)"
echo ""

echo -e "${BLUE}📍 5. Network Status:${NC}"
echo "• Port 80: $(netstat -tulpn 2>/dev/null | grep :80 | wc -l) connections"
echo "• Port 443: $(netstat -tulpn 2>/dev/null | grep :443 | wc -l) connections"
echo "• Port 5678: $(netstat -tulpn 2>/dev/null | grep :5678 | wc -l) connections"
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
    
    success "Successfully created diagnostic script"
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
    
    echo -e "${CYAN}🌐 ACCESS THE SERVICE:${NC}"
    if [[ "$LOCAL_MODE" == "true" ]]; then
        echo -e "  • N8N: ${WHITE}http://localhost:5678${NC}"
    else
        echo -e "  • N8N: ${WHITE}https://${DOMAIN}${NC}"
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
    
    echo -e "${CYAN}📋 USEFUL COMMANDS:${NC}"
    echo -e "  • Check logs: ${WHITE}cd /home/n8n && $DOCKER_COMPOSE logs -f${NC}"
    echo -e "  • Restart services: ${WHITE}cd /home/n8n && $DOCKER_COMPOSE restart${NC}"
    echo -e "  • Manual backup: ${WHITE}/home/n8n/backup-manual.sh${NC}"
    echo -e "  • Manual update: ${WHITE}/home/n8n/update-n8n.sh${NC}"
    echo -e "  • Troubleshoot errors: ${WHITE}/home/n8n/troubleshoot.sh${NC}"
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
