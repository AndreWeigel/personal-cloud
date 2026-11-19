#!/usr/bin/env bash
# =============================================================================
# deploy-service.sh — Deploy or update a single service
# =============================================================================
# Copies the Docker Compose file and Nginx config into place, then starts
# (or restarts) the service.
#
# Usage:
#   chmod +x deploy-service.sh
#   sudo ./scripts/deploy-service.sh vaultwarden
#   sudo ./scripts/deploy-service.sh nextcloud
#   sudo ./scripts/deploy-service.sh immich
# =============================================================================

set -euo pipefail

GREEN='\033[0;32m'; RED='\033[0;31m'; NC='\033[0m'
info()  { echo -e "${GREEN}[deploy]${NC} $*"; }
error() { echo -e "${RED}[deploy]${NC} $*" >&2; exit 1; }

# ---------------------------------------------------------------------------
# Validate input
# ---------------------------------------------------------------------------
SERVICE="${1:-}"
if [[ -z "$SERVICE" ]]; then
    error "Usage: $0 <service-name>  (e.g. vaultwarden, nextcloud, immich)"
fi

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
COMPOSE_SRC="$REPO_ROOT/services/$SERVICE/docker-compose.yml"
NGINX_SRC="$REPO_ROOT/nginx/$SERVICE.conf"
SERVICE_DIR="$HOME/$SERVICE"

# ---------------------------------------------------------------------------
# Check that source files exist
# ---------------------------------------------------------------------------
[[ -f "$COMPOSE_SRC" ]] || error "No docker-compose.yml found at $COMPOSE_SRC"

# ---------------------------------------------------------------------------
# 1. Copy Docker Compose file
# ---------------------------------------------------------------------------
info "Copying docker-compose.yml to $SERVICE_DIR/..."
mkdir -p "$SERVICE_DIR"
cp "$COMPOSE_SRC" "$SERVICE_DIR/docker-compose.yml"

# Repo-managed config (e.g. homepage/config) — overwrites tracked files only.
if [[ -d "$REPO_ROOT/services/$SERVICE/config" ]]; then
    mkdir -p "$SERVICE_DIR/config"
    cp -r "$REPO_ROOT/services/$SERVICE/config/." "$SERVICE_DIR/config/"
    info "config/ copied to $SERVICE_DIR/config/"
fi

# ---------------------------------------------------------------------------
# 2. Copy .env if it exists in the repo root
# ---------------------------------------------------------------------------
if [[ -f "$REPO_ROOT/.env" ]]; then
    cp "$REPO_ROOT/.env" "$SERVICE_DIR/.env"
    info ".env copied to $SERVICE_DIR/"
else
    echo "  No .env found in repo root — make sure $SERVICE_DIR/.env exists before starting."
fi

# ---------------------------------------------------------------------------
# 3. Install Nginx config + reload (skipped for tunnel-only services: wud, homepage)
# ---------------------------------------------------------------------------
if [[ -f "$NGINX_SRC" ]]; then
    NGINX_DEST="/etc/nginx/sites-available/$SERVICE.conf"
    NGINX_LINK="/etc/nginx/sites-enabled/$SERVICE.conf"

    info "Installing Nginx config to $NGINX_DEST..."
    cp "$NGINX_SRC" "$NGINX_DEST"

    if [[ ! -L "$NGINX_LINK" ]]; then
        ln -s "$NGINX_DEST" "$NGINX_LINK"
        info "Symlink created: $NGINX_LINK"
    else
        info "Nginx symlink already exists, skipping."
    fi

    info "Testing Nginx configuration..."
    nginx -t || error "Nginx config test failed — fix the config before continuing."

    info "Reloading Nginx..."
    systemctl reload nginx
else
    info "No nginx/$SERVICE.conf — tunnel-only service, skipping Nginx."
fi

# ---------------------------------------------------------------------------
# 4. Start or restart the service
# ---------------------------------------------------------------------------
info "Starting $SERVICE with Docker Compose..."
cd "$SERVICE_DIR"
docker compose up -d

info "Done! $SERVICE is running."
echo "  Logs: docker compose -f $SERVICE_DIR/docker-compose.yml logs -f"
