#!/usr/bin/env bash
# =============================================================================
# bootstrap.sh — Initial setup for a fresh Ubuntu 24.04 server
# =============================================================================
# Run once on a brand-new server to install all dependencies and harden it.
# Designed to be idempotent: safe to run more than once.
#
# Usage:
#   chmod +x bootstrap.sh
#   sudo ./bootstrap.sh
# =============================================================================

set -euo pipefail

# Colour helpers
GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
info()    { echo -e "${GREEN}[bootstrap]${NC} $*"; }
warning() { echo -e "${YELLOW}[bootstrap]${NC} $*"; }

# Must run as root
if [[ $EUID -ne 0 ]]; then
    echo "Please run this script as root (sudo ./bootstrap.sh)"
    exit 1
fi

# ---------------------------------------------------------------------------
# 1. System update
# ---------------------------------------------------------------------------
info "Updating system packages..."
apt update -q
apt upgrade -y -q
apt autoremove -y -q

# ---------------------------------------------------------------------------
# 2. Install Docker
# ---------------------------------------------------------------------------
if command -v docker &>/dev/null; then
    info "Docker already installed, skipping."
else
    info "Installing Docker..."
    apt install -y -q ca-certificates curl gnupg lsb-release
    install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
        | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    chmod a+r /etc/apt/keyrings/docker.gpg
    echo \
        "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
        https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" \
        | tee /etc/apt/sources.list.d/docker.list > /dev/null
    apt update -q
    apt install -y -q docker-ce docker-ce-cli containerd.io docker-compose-plugin
    systemctl enable docker
    systemctl start docker
    info "Docker installed."
fi

# ---------------------------------------------------------------------------
# 3. Install Nginx
# ---------------------------------------------------------------------------
if command -v nginx &>/dev/null; then
    info "Nginx already installed, skipping."
else
    info "Installing Nginx..."
    apt install -y -q nginx
    systemctl enable nginx
    systemctl start nginx
    info "Nginx installed."
fi

# ---------------------------------------------------------------------------
# 4. Install Certbot (Let's Encrypt)
# ---------------------------------------------------------------------------
if command -v certbot &>/dev/null; then
    info "Certbot already installed, skipping."
else
    info "Installing Certbot..."
    apt install -y -q certbot python3-certbot-nginx
    info "Certbot installed."
fi

# ---------------------------------------------------------------------------
# 5. Install Fail2Ban
# ---------------------------------------------------------------------------
if command -v fail2ban-client &>/dev/null; then
    info "Fail2Ban already installed, skipping."
else
    info "Installing Fail2Ban..."
    apt install -y -q fail2ban
fi

# Write Fail2Ban jail config
cat > /etc/fail2ban/jail.local <<'EOF'
[DEFAULT]
# Ban for 1 hour after 5 failures in 10 minutes
maxretry = 5
findtime = 600
bantime  = 3600

[sshd]
enabled = true
port    = ssh
logpath = /var/log/auth.log

[nginx-http-auth]
enabled  = true
port     = http,https
logpath  = /var/log/nginx/error.log

[nginx-botsearch]
enabled  = true
port     = http,https
logpath  = /var/log/nginx/access.log
maxretry = 2
EOF

systemctl enable fail2ban
systemctl restart fail2ban
info "Fail2Ban configured."

# ---------------------------------------------------------------------------
# 6. Configure UFW firewall
# ---------------------------------------------------------------------------
info "Configuring UFW firewall..."
apt install -y -q ufw
ufw --force reset
ufw default deny incoming
ufw default allow outgoing
ufw allow 22/tcp   comment 'SSH'
ufw allow 80/tcp   comment 'HTTP'
ufw allow 443/tcp  comment 'HTTPS'
ufw --force enable
info "UFW enabled. Allowed ports: 22, 80, 443."

# ---------------------------------------------------------------------------
# 7. Harden SSH — disable password authentication
# ---------------------------------------------------------------------------
info "Hardening SSH config..."
SSHD_CONFIG=/etc/ssh/sshd_config

# Disable password login
sed -i 's/^#\?PasswordAuthentication.*/PasswordAuthentication no/' "$SSHD_CONFIG"
# Disable root login
sed -i 's/^#\?PermitRootLogin.*/PermitRootLogin prohibit-password/' "$SSHD_CONFIG"

systemctl restart sshd
info "SSH hardened (key-only auth)."

# ---------------------------------------------------------------------------
# 8. Create service directories
# ---------------------------------------------------------------------------
info "Creating service directories..."
HOME_DIR="${SUDO_HOME:-/root}"
for svc in vaultwarden nextcloud immich jellyfin; do
    mkdir -p "$HOME_DIR/$svc/data"
done
mkdir -p "$HOME_DIR/nextcloud/db"
info "Directories created under $HOME_DIR/."

# ---------------------------------------------------------------------------
# Done
# ---------------------------------------------------------------------------
echo ""
info "Bootstrap complete! Next steps:"
echo "  1. Copy .env.example to .env and fill in your secrets"
echo "  2. Copy your Docker Compose files to ~/vaultwarden/, ~/nextcloud/, etc."
echo "  3. Copy Nginx configs to /etc/nginx/sites-available/ and enable them"
echo "  4. Run ./scripts/ssl-setup.sh <subdomain> for each service"
echo "  5. Run docker compose up -d in each service directory"
echo ""
warning "Important: make sure your DNS A records point to this server before running Certbot!"
