# Security

Security measures in place for the personal-cloud server.

---

## Network Perimeter

**UFW firewall** — only three ports are open inbound:

| Port | Protocol | Purpose |
|------|----------|---------|
| 22 | TCP | SSH |
| 80 | TCP | HTTP (redirected to HTTPS by Nginx) |
| 443 | TCP | HTTPS |

All other inbound traffic is dropped. Outbound is unrestricted.

Additionally, Hetzner's Cloud Firewall (managed via Pulumi in [../infra/index.ts](../infra/index.ts)) enforces the same rules at the network level, before traffic even reaches the server.

---

## SSH Hardening

- **Password authentication disabled** — SSH key only (`PasswordAuthentication no`)
- **Root login restricted** to key-only (`PermitRootLogin prohibit-password`)
- Applied via `/etc/ssh/sshd_config.d/hardening.conf` (drop-in, survives package updates)

---

## Fail2Ban

Three active jails:

| Jail | Watches | Threshold |
|------|---------|-----------|
| `sshd` | `/var/log/auth.log` | 5 failures in 10 min → 1 hr ban |
| `nginx-http-auth` | `/var/log/nginx/error.log` | 5 failures in 10 min → 1 hr ban |
| `nginx-botsearch` | `/var/log/nginx/access.log` | 2 failures in 10 min → 1 hr ban |

Config lives in `/etc/fail2ban/jail.local` (written by `bootstrap.sh`).

View active bans:
```bash
sudo fail2ban-client status sshd
```

---

## TLS / SSL

- All services use **Let's Encrypt certificates** (free, auto-renewing)
- Certbot runs in Nginx mode — it handles certificate issuance and Nginx config updates
- HTTP is automatically redirected to HTTPS by Nginx after Certbot runs
- **HSTS** is set on Nextcloud: `Strict-Transport-Security: max-age=31536000; includeSubDomains; preload`

---

## Service-Level Security

**Vaultwarden:**
- Public signups disabled (`SIGNUPS_ALLOWED=false`)
- Admin panel protected by a token (generated with `openssl rand -base64 48`)
- Container only binds to localhost (`127.0.0.1:8080`) — not accessible directly from outside

**Nextcloud:**
- Runs behind Nginx with `X-Frame-Options`, `X-Content-Type-Options` headers
- Database credentials are environment variables, not hardcoded
- MariaDB container does not expose any ports externally

**All services:**
- Docker containers bind only to `127.0.0.1` — Nginx is the single external entry point
- Credentials are stored in `.env` files, which are excluded from git via `.gitignore`

---

## What This Repo Does NOT Contain

- No passwords, tokens, or API keys
- No SSH private keys
- No SSL certificates or private keys
- No `.env` files (only `.env.example` with placeholder values)

The `.gitignore` enforces this — see [../.gitignore](../.gitignore).

---

## Recommended Improvements

- [ ] Restrict SSH port 22 in UFW to your home IP (`ufw allow from <your-ip> to any port 22`)
- [ ] Enable two-factor authentication on the Hetzner Cloud account
- [ ] Set up automatic security updates (`unattended-upgrades`)
- [ ] Consider Crowdsec as a more modern alternative to Fail2Ban
- [ ] Add monitoring / alerting (Uptime Kuma planned)
