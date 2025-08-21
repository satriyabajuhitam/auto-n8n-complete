#!/bin/bash
# =============================================================================
# 🚀 AUTOMATED N8N INSTALLATION SCRIPT 2025 - FIXED PRODUCTION BUILD
# =============================================================================
# Updated: 21/08/2025 (Asia/Jakarta)
# =============================================================================

set -Eeuo pipefail

# Colors
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; CYAN='\033[0;36m'; WHITE='\033[1;37m'; NC='\033[0m'

# Globals
INSTALL_DIR="/home/n8n"
DOMAIN=""
N8N_ENCRYPTION_KEY=""
CLEAN_INSTALL=false
LOCAL_MODE=false

# DB (default SQLite)
USE_POSTGRES=false
DB_USER="n8n"
DB_PASSWORD=""
DB_NAME="n8n"
DB_HOST="postgres"

show_banner() {
  clear || true
  echo -e "${CYAN}╔══════════════════════════════════════════════════════════════════════════════╗${NC}"
  echo -e "${CYAN}║${WHITE}           🚀 AUTOMATED N8N INSTALLATION SCRIPT 2025 - PRODUCTION 🚀           ${CYAN}║${NC}"
  echo -e "${CYAN}╠══════════════════════════════════════════════════════════════════════════════╣${NC}"
  echo -e "${CYAN}║${WHITE} ✨ N8N + FFmpeg + yt-dlp + PostgreSQL/SQLite + Caddy (HTTPS)              ${CYAN}║${NC}"
  echo -e "${CYAN}╠══════════════════════════════════════════════════════════════════════════════╣${NC}"
  echo -e "${CYAN}║${YELLOW} 📅 Updated: 21/08/2025 (Asia/Jakarta)                                      ${CYAN}║${NC}"
  echo -e "${CYAN}╚══════════════════════════════════════════════════════════════════════════════╝${NC}\n"
}

log()      { echo -e "${GREEN}[$(date +'%F %T')] $*${NC}"; }
warn()     { echo -e "${YELLOW}[WARN] $*${NC}"; }
err()      { echo -e "${RED}[ERROR] $*${NC}" >&2; }
info()     { echo -e "${BLUE}[INFO]  $*${NC}"; }
trap 'err "Gagal di baris $LINENO"; exit 1' ERR

need_root() {
  if [[ $EUID -ne 0 ]]; then
    err "Jalankan sebagai root (sudo)."
    exit 1
  fi
}

get_installation_mode() {
  read -p "🏠 Install Local Mode (expose port 5678 langsung)? (y/N): " -n 1 -r; echo
  if [[ $REPLY =~ ^[Yy]$ ]]; then
    LOCAL_MODE=true; DOMAIN="localhost"
  else
    LOCAL_MODE=false
  fi
}

get_domain_input() {
  if $LOCAL_MODE; then info "Local Mode: DOMAIN=localhost"; return; fi
  while [[ -z "${DOMAIN}" ]]; do
    read -rp "🌐 Domain untuk n8n (mis. n8n.example.com): " DOMAIN
    [[ -z "$DOMAIN" ]] && err "Domain tidak boleh kosong."
  done
}

get_database_config() {
  echo -e "\n${WHITE}DB Options:${NC} SQLite (default) atau PostgreSQL (disarankan untuk produksi)."
  read -p "🐘 Pakai PostgreSQL? (y/N): " -n 1 -r; echo
  if [[ $REPLY =~ ^[Yy]$ ]]; then
    USE_POSTGRES=true
    command -v openssl >/dev/null 2>&1 || apt-get update -y && apt-get install -y openssl
    DB_PASSWORD=$(openssl rand -base64 24)
    info "Postgres diaktifkan. User=$DB_USER DB=$DB_NAME Password di-generate."
  else
    USE_POSTGRES=false
  fi
}

get_cleanup_option() {
  if [[ -d "$INSTALL_DIR" ]]; then
    warn "Install lama terdeteksi di: $INSTALL_DIR"
    read -p "🗑️ Hapus & install baru? (y/N): " -n 1 -r; echo
    [[ $REPLY =~ ^[Yy]$ ]] && CLEAN_INSTALL=true
  fi
}

cleanup_old_installation() {
  $CLEAN_INSTALL || return 0
  log "🗑️ Menghapus instalasi lama..."
  pushd "$INSTALL_DIR" >/dev/null 2>&1 || true
  if command -v docker >/dev/null 2>&1 && docker compose version >/dev/null 2>&1; then
    docker compose down --volumes --remove-orphans || true
  fi
  popd >/dev/null 2>&1 || true
  rm -rf "$INSTALL_DIR"
  log "✅ Cleanup selesai."
}

install_docker() {
  if command -v docker >/dev/null 2>&1; then
    info "Docker sudah terpasang."
  else
    log "📦 Memasang Docker & Compose plugin..."
    apt-get update -y
    apt-get install -y ca-certificates curl gnupg lsb-release openssl
    install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
    chmod a+r /etc/apt/keyrings/docker.asc
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" \
      > /etc/apt/sources.list.d/docker.list
    apt-get update -y
    apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
  fi
  systemctl enable --now docker || true
}

create_project_structure() {
  log "📁 Membuat struktur proyek..."
  mkdir -p "$INSTALL_DIR"/{files,logs}
}

setup_env_file() {
  log "🔐 Menulis .env (host)..."
  [[ -z "$N8N_ENCRYPTION_KEY" ]] && N8N_ENCRYPTION_KEY=$(openssl rand -hex 32)
  cat > "$INSTALL_DIR/.env" <<EOF
# === n8n host env ===
N8N_ENCRYPTION_KEY=${N8N_ENCRYPTION_KEY}
GENERIC_TIMEZONE=Asia/Jakarta
TZ=Asia/Jakarta
# Postgres (jika dipakai)
POSTGRES_USER=${DB_USER}
POSTGRES_PASSWORD=${DB_PASSWORD}
POSTGRES_DB=${DB_NAME}
EOF
  chmod 600 "$INSTALL_DIR/.env"
}

create_dockerfile() {
  log "🐳 Membuat Dockerfile untuk n8n + ffmpeg + yt-dlp..."
  # Catatan: image n8n berbasis Alpine -> gunakan apk. (lihat docs / registry)
  cat > "$INSTALL_DIR/Dockerfile" <<'EOF'
FROM docker.n8n.io/n8nio/n8n:latest

USER root
# ffmpeg + python + pip + alat build minimal untuk wheel ringan
RUN apk add --no-cache ffmpeg python3 py3-pip build-base linux-headers \
 && pip3 install --no-cache-dir yt-dlp \
 && rm -rf /var/cache/apk/*
USER node
EOF
}

create_caddyfile() {
  $LOCAL_MODE && return 0
  log "🌐 Membuat Caddyfile (HTTPS otomatis)..."
  cat > "$INSTALL_DIR/Caddyfile" <<EOF
{
    email admin@${DOMAIN}
}

${DOMAIN} {
    reverse_proxy n8n:5678
}
EOF
}

create_docker_compose() {
  log "🧩 Membuat docker-compose.yml..."
  local DOCKER_COMPOSE_FILE="$INSTALL_DIR/docker-compose.yml"

  # Blok env n8n (berbeda untuk local vs production)
  local N8N_ENV
  if $LOCAL_MODE; then
read -r -d '' N8N_ENV <<EOF
    ports:
      - "5678:5678"
    environment:
      N8N_HOST: "localhost"
      N8N_PORT: "5678"
      N8N_PROTOCOL: "http"
      N8N_EDITOR_BASE_URL: "http://localhost:5678/"
      WEBHOOK_URL: "http://localhost:5678/"
      N8N_RUNNERS_ENABLED: "true"
      N8N_ENFORCE_SETTINGS_FILE_PERMISSIONS: "true"
EOF
  else
read -r -d '' N8N_ENV <<EOF
    ports:
      - "127.0.0.1:5678:5678"
    environment:
      N8N_HOST: "${DOMAIN}"
      N8N_PORT: "443"
      N8N_PROTOCOL: "https"
      N8N_EDITOR_BASE_URL: "https://${DOMAIN}/"
      WEBHOOK_URL: "https://${DOMAIN}/"
      N8N_RUNNERS_ENABLED: "true"
      N8N_ENFORCE_SETTINGS_FILE_PERMISSIONS: "true"
EOF
  fi

  # Tambahkan konfigurasi DB
  if $USE_POSTGRES; then
read -r -d '' N8N_DB <<'EOF'
      DB_TYPE: "postgresdb"
      DB_POSTGRESDB_HOST: "postgres"
      DB_POSTGRESDB_USER: "${POSTGRES_USER}"
      DB_POSTGRESDB_PASSWORD: "${POSTGRES_PASSWORD}"
      DB_POSTGRESDB_DATABASE: "${POSTGRES_DB}"
      DB_POSTGRESDB_PORT: "5432"
EOF
  else
read -r -d '' N8N_DB <<'EOF'
      DB_TYPE: "sqlite"
      DB_SQLITE_DATABASE: "/home/node/.n8n/database.sqlite"
EOF
  fi

  # Tulis compose
  cat > "$DOCKER_COMPOSE_FILE" <<EOF
services:
  n8n:
    build: .
    container_name: n8n-container
    restart: unless-stopped
    env_file: .env
    volumes:
      - ./files:/home/node/.n8n
    networks:
      - n8n_network
${N8N_ENV}
${N8N_DB}
EOF

  if $USE_POSTGRES; then
    cat >> "$DOCKER_COMPOSE_FILE" <<'EOF'
    depends_on:
      postgres:
        condition: service_healthy
EOF
  fi

  if ! $LOCAL_MODE; then
    cat >> "$DOCKER_COMPOSE_FILE" <<'EOF'

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
  fi

  if $USE_POSTGRES; then
    cat >> "$DOCKER_COMPOSE_FILE" <<'EOF'

  postgres:
    image: postgres:15-alpine
    container_name: postgres-container
    restart: unless-stopped
    env_file: .env
    volumes:
      - postgres_data:/var/lib/postgresql/data
    networks:
      - n8n_network
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U ${POSTGRES_USER} -d ${POSTGRES_DB}"]
      interval: 10s
      timeout: 5s
      retries: 5
EOF
  fi

  # volumes & networks
  {
    echo
    echo "volumes:"
    $USE_POSTGRES && echo "  postgres_data:"
    if ! $LOCAL_MODE; then
      echo "  caddy_data:"
      echo "  caddy_config:"
    fi
    echo
    echo "networks:"
    echo "  n8n_network:"
    echo "    driver: bridge"
  } >> "$DOCKER_COMPOSE_FILE"

  log "✅ docker-compose.yml dibuat."
}

create_troubleshooting_script() {
  cat > "$INSTALL_DIR/troubleshoot.sh" <<'EOF'
#!/bin/bash
cd /home/n8n || exit 1
echo "=== Compose PS ==="
docker compose ps
echo
echo "=== Logs: n8n (tail 100) ==="
docker compose logs --tail 100 n8n
echo
if docker compose ps caddy >/dev/null 2>&1; then
  echo "=== Logs: caddy (tail 50) ==="
  docker compose logs --tail 50 caddy
fi
if docker compose ps postgres >/dev/null 2>&1; then
  echo "=== Logs: postgres (tail 50) ==="
  docker compose logs --tail 50 postgres
fi
EOF
  chmod +x "$INSTALL_DIR/troubleshoot.sh"
}

build_and_deploy() {
  log "🏗️ Build & deploy containers..."
  cd "$INSTALL_DIR"
  chown -R 1000:1000 "$INSTALL_DIR/files"
  docker compose up -d --build --force-recreate --remove-orphans
  log "⏳ Tunggu 30 detik agar layanan siap..."
  sleep 30
}

show_final_summary() {
  echo -e "\n${GREEN}🎉 N8N sukses di-install!${NC}"
  if $LOCAL_MODE; then
    echo -e "🌐 Akses: ${WHITE}http://localhost:5678${NC}"
  else
    echo -e "🌐 Akses: ${WHITE}https://${DOMAIN}${NC}"
  fi
  echo -e "🔧 Diagnostik cepat: ${YELLOW}bash /home/n8n/troubleshoot.sh${NC}"
}

main() {
  show_banner
  need_root
  get_installation_mode
  get_domain_input
  get_database_config
  get_cleanup_option
  $CLEAN_INSTALL && cleanup_old_installation
  install_docker
  create_project_structure
  setup_env_file
  create_dockerfile
  create_caddyfile
  create_docker_compose
  create_troubleshooting_script
  build_and_deploy
  show_final_summary
}

main "$@"
