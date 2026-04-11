#!/usr/bin/env bash
# =============================================================================
# backup.sh — Local backup of service configs and data
# =============================================================================
# Creates timestamped archives of service directories.
# NOTE: This is a supplementary local backup script.
#       Primary backups are handled by Hetzner's automatic server snapshots.
#
# What it backs up:
#   - ~/vaultwarden/data/   (encrypted vault items)
#   - ~/nextcloud/data/     (Nextcloud app data)
#   - ~/nextcloud/db/       (MariaDB data — stopped first for consistency)
#
# What it does NOT back up:
#   - User files on the Storage Box (those are already on Hetzner infrastructure)
#
# Usage:
#   chmod +x backup.sh
#   sudo ./scripts/backup.sh
#
# Automate it with cron (e.g. daily at 2am):
#   0 2 * * * /home/user/personal-cloud/scripts/backup.sh >> /var/log/backup.log 2>&1
# =============================================================================

set -euo pipefail

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
info()    { echo -e "${GREEN}[backup]${NC} $*"; }
warning() { echo -e "${YELLOW}[backup]${NC} $*"; }

TIMESTAMP="$(date +%Y%m%d-%H%M%S)"
BACKUP_DIR="${BACKUP_DEST:-/var/backups/personal-cloud}"
mkdir -p "$BACKUP_DIR"

HOME_DIR="${SUDO_HOME:-$HOME}"

# ---------------------------------------------------------------------------
# Vaultwarden backup (container can stay running — data dir is safe to copy)
# ---------------------------------------------------------------------------
if [[ -d "$HOME_DIR/vaultwarden/data" ]]; then
    info "Backing up Vaultwarden data..."
    tar -czf "$BACKUP_DIR/vaultwarden-$TIMESTAMP.tar.gz" \
        -C "$HOME_DIR/vaultwarden" data/
    info "  Saved to $BACKUP_DIR/vaultwarden-$TIMESTAMP.tar.gz"
else
    warning "Vaultwarden data directory not found, skipping."
fi

# ---------------------------------------------------------------------------
# Nextcloud backup (stop DB for a consistent snapshot)
# ---------------------------------------------------------------------------
if [[ -d "$HOME_DIR/nextcloud" ]]; then
    info "Stopping Nextcloud DB for consistent backup..."
    docker compose -f "$HOME_DIR/nextcloud/docker-compose.yml" stop nextcloud-db 2>/dev/null || true

    info "Backing up Nextcloud data and DB..."
    tar -czf "$BACKUP_DIR/nextcloud-data-$TIMESTAMP.tar.gz" \
        -C "$HOME_DIR/nextcloud" data/
    tar -czf "$BACKUP_DIR/nextcloud-db-$TIMESTAMP.tar.gz" \
        -C "$HOME_DIR/nextcloud" db/

    info "Restarting Nextcloud DB..."
    docker compose -f "$HOME_DIR/nextcloud/docker-compose.yml" start nextcloud-db 2>/dev/null || true

    info "  Saved to $BACKUP_DIR/nextcloud-{data,db}-$TIMESTAMP.tar.gz"
else
    warning "Nextcloud directory not found, skipping."
fi

# ---------------------------------------------------------------------------
# Rotate old backups — keep the last 7 days
# ---------------------------------------------------------------------------
info "Removing backups older than 7 days..."
find "$BACKUP_DIR" -name "*.tar.gz" -mtime +7 -delete

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
echo ""
info "Backup complete at $TIMESTAMP"
info "Backup location: $BACKUP_DIR"
du -sh "$BACKUP_DIR"
echo ""
warning "Remember: primary backups are Hetzner server snapshots."
warning "Consider copying these archives off-server for redundancy."
