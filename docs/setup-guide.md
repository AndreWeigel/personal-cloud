# Setup Guide

Complete walkthrough for setting up the personal-cloud stack from scratch.

---

## Prerequisites

- A Hetzner Cloud account and API token
- A domain name (this guide uses `yourdomain.com`)
- An SSH key pair (`ssh-keygen -t ed25519` if you don't have one)
- Your SSH public key uploaded to [Hetzner Cloud → Security → SSH Keys](https://console.hetzner.cloud)

---

## Step 1: Provision the Server with Pulumi

See [../infra/](../infra/) for the Pulumi program.

```bash
cd infra
npm install

# Initialise a new stack named "prod"
pulumi stack init prod

# Set your Hetzner API token (stored encrypted — never in plain files)
pulumi config set --secret hcloudToken <YOUR_HETZNER_API_TOKEN>

# Preview what will be created
pulumi preview

# Apply
pulumi up
```

Note the server IP from the stack outputs. Create DNS A records for each subdomain before proceeding.

**DNS records to create** (at your registrar or DNS provider):

| Record | Type | Value |
|--------|------|-------|
| `vault.yourdomain.com` | A | `<server-ip>` |
| `cloud.yourdomain.com` | A | `<server-ip>` |
| `photos.yourdomain.com` | A | `<server-ip>` (future) |

DNS propagation can take a few minutes to a few hours.

---

## Step 2: Bootstrap the Server

SSH in and run the bootstrap script. It installs Docker, Nginx, Certbot, Fail2Ban, and configures UFW.

```bash
ssh root@<server-ip>
git clone https://github.com/AndreWeigel/personal-cloud.git
cd personal-cloud
sudo ./scripts/bootstrap.sh
```

What the script does:
1. Updates all system packages
2. Installs Docker + Docker Compose plugin
3. Installs Nginx
4. Installs Certbot + nginx plugin
5. Configures Fail2Ban (SSH, nginx-http-auth, nginx-botsearch jails)
6. Configures UFW (allow 22, 80, 443 only)
7. Disables password SSH login (key-only)
8. Creates service directories under `~/`

---

## Step 3: Configure Your Secrets

```bash
cp .env.example .env
nano .env
```

Fill in every variable — see [../.env.example](../.env.example) for descriptions.

Generate a secure Vaultwarden admin token:
```bash
openssl rand -base64 48
```

---

## Step 4: Deploy Vaultwarden

```bash
sudo ./scripts/deploy-service.sh vaultwarden
sudo ./scripts/ssl-setup.sh vault.yourdomain.com
```

This will:
- Copy `services/vaultwarden/docker-compose.yml` to `~/vaultwarden/`
- Install the Nginx config and enable it
- Start the container
- Obtain an SSL certificate and update Nginx automatically

Verify it's running:
```bash
docker ps | grep vaultwarden
curl -I https://vault.yourdomain.com
```

---

## Step 5: Deploy Nextcloud

Nextcloud uses an SFTP external storage for user files via Hetzner Storage Box. Mount it first:

```bash
# Install sshfs
apt install -y sshfs

# Create the mount point
mkdir -p /mnt/storagebox/nextcloud

# Mount (replace with your Storage Box credentials)
sshfs -o allow_other,reconnect,ServerAliveInterval=15 \
    uXXXXXX@uXXXXXX.your-storagebox.de:/nextcloud \
    /mnt/storagebox/nextcloud

# Make it persistent — add to /etc/fstab:
# uXXXXXX@uXXXXXX.your-storagebox.de:/nextcloud /mnt/storagebox/nextcloud fuse.sshfs defaults,allow_other,reconnect,_netdev 0 0
```

Then deploy:
```bash
sudo ./scripts/deploy-service.sh nextcloud
sudo ./scripts/ssl-setup.sh cloud.yourdomain.com
```

After deploying, set up the background cron job for Nextcloud:
```bash
crontab -e
# Add:
*/5 * * * * docker exec -u www-data nextcloud php /var/www/html/cron.php
```

In the Nextcloud admin panel:
1. Go to **Settings → Basic Settings → Background Jobs** → select **Cron**
2. Go to **Settings → External Storages** and add the Storage Box mount at `/mnt/storagebox/nextcloud`

---

## Step 6: Verify Everything

```bash
# All containers running
docker ps

# Nginx status
systemctl status nginx

# Fail2Ban jails active
sudo fail2ban-client status

# UFW rules
sudo ufw status verbose

# Test SSL
curl -I https://vault.yourdomain.com
curl -I https://cloud.yourdomain.com
```

---

## Maintenance

**Update a service:**
```bash
cd ~/vaultwarden   # or ~/nextcloud
docker compose pull
docker compose up -d
```

**View logs:**
```bash
docker compose -f ~/vaultwarden/docker-compose.yml logs -f
```

**Renew SSL certificates (auto, but can test manually):**
```bash
sudo certbot renew --dry-run
```

**Run a backup:**
```bash
sudo ./scripts/backup.sh
```
