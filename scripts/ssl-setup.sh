#!/usr/bin/env bash
# =============================================================================
# ssl-setup.sh — Obtain a Let's Encrypt SSL certificate for a subdomain
# =============================================================================
# Runs Certbot in Nginx mode: it obtains a certificate and automatically
# updates the Nginx config to redirect HTTP to HTTPS.
#
# Prerequisites:
#   - Nginx is installed and the site config is in sites-enabled
#   - DNS A record for the subdomain points to this server
#   - Ports 80 and 443 are open (UFW / Hetzner firewall)
#
# Usage:
#   chmod +x ssl-setup.sh
#   sudo ./scripts/ssl-setup.sh vault.yourdomain.com
#   sudo ./scripts/ssl-setup.sh cloud.yourdomain.com
# =============================================================================

set -euo pipefail

GREEN='\033[0;32m'; RED='\033[0;31m'; NC='\033[0m'
info()  { echo -e "${GREEN}[ssl-setup]${NC} $*"; }
error() { echo -e "${RED}[ssl-setup]${NC} $*" >&2; exit 1; }

DOMAIN="${1:-}"
if [[ -z "$DOMAIN" ]]; then
    error "Usage: $0 <domain>  (e.g. vault.yourdomain.com)"
fi

# Check Certbot is installed
command -v certbot &>/dev/null || error "Certbot is not installed. Run bootstrap.sh first."

info "Obtaining SSL certificate for $DOMAIN..."
certbot --nginx -d "$DOMAIN" --agree-tos --no-eff-email --redirect

info "SSL certificate obtained and Nginx updated for $DOMAIN."
info "Certificate will auto-renew via the systemd certbot timer."
echo ""
echo "  Verify auto-renewal with: sudo certbot renew --dry-run"
