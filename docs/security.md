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
- **HSTS** (`Strict-Transport-Security: max-age=31536000; includeSubDomains; preload`) is set on all domains

---

## Nginx Hardening

- **`server_tokens off`** — Nginx does not reveal its version in response headers
- All domains return the following security headers:
  - `Strict-Transport-Security` — forces HTTPS for 1 year
  - `X-Frame-Options: SAMEORIGIN` — prevents clickjacking
  - `X-Content-Type-Options: nosniff` — prevents MIME sniffing
  - `Referrer-Policy: strict-origin-when-cross-origin`

---

## Service-Level Security

**Vaultwarden:**
- Public signups disabled (`SIGNUPS_ALLOWED=false`)
- Admin panel protected by a token (generated with `openssl rand -base64 48`)
- Container only binds to localhost (`127.0.0.1:8080`) — not accessible directly from outside

**Nextcloud:**
- Runs behind Nginx with full security headers
- Database credentials are environment variables, never hardcoded
- MariaDB and Redis containers do not expose any ports externally

**Immich:**
- No public registration in v2.x — users can only be created by admin
- Container binds to localhost only (`127.0.0.1:2283`)

**Jellyfin:**
- Setup wizard completed — public account creation not possible
- Container binds to localhost only (`127.0.0.1:8096`)
- Media library mounted read-only (`:ro`) — a compromised container cannot modify media files

**Navidrome:**
- Public registration disabled (`ND_ENABLEUSERCREATION=false`)
- Container binds to localhost only (`127.0.0.1:4533`)
- Music library mounted read-only (`:ro`)

**Uptime Kuma:**
- Single admin account, no public registration

**All services:**
- Docker containers bind only to `127.0.0.1` — Nginx is the single external entry point
- Credentials are stored in `.env` files, excluded from git via `.gitignore`
- `no-new-privileges:true` set on Jellyfin and Navidrome containers

---

## What This Repo Does NOT Contain

- No passwords, tokens, or API keys
- No SSH private keys
- No SSL certificates or private keys
- No `.env` files (only `.env.example` with placeholder values)
- No server IP address

The `.gitignore` enforces this — see [../.gitignore](../.gitignore).

---

## Recommended Improvements

- [ ] **WireGuard VPN** — expose SSH only through the VPN tunnel, removing port 22 from the public internet entirely. Better than IP-restricting UFW since it works from any network.
- [ ] **2FA on Hetzner Cloud account** — console access bypasses all server-level security; protecting the Hetzner account is important.
- [ ] Consider Crowdsec as a more modern alternative to Fail2Ban
