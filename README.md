# personal-cloud

A self-hosted personal cloud running on a single Hetzner VPS — open source, European, and fully under my control.

```
Browser
   │
   ▼
Nginx (reverse proxy + SSL)
   │
   ├── andreweigel.me / www     ──▶  Static landing page (/var/www/andreweigel.me)
   ├── vault.andreweigel.me     ──▶  Vaultwarden  (localhost:8080)
   ├── cloud.andreweigel.me     ──▶  Nextcloud    (localhost:8081)
   │                                     │
   │                                     ├── MariaDB     (container)
   │                                     ├── Redis       (container)
   │                                     └── User files  ──▶  Hetzner Storage Box (sshfs)
   │
   ├── photos.andreweigel.me    ──▶  Immich       (localhost:2283)
   ├── media.andreweigel.me     ──▶  Jellyfin     (localhost:8096)
   ├── music.andreweigel.me     ──▶  Navidrome      (localhost:4533)
   ├── audiobooks.andreweigel.me──▶  Audiobookshelf (localhost:13378)
   ├── books.andreweigel.me     ──▶  Calibre-Web  (localhost:8083)
   ├── do.andreweigel.me        ──▶  Vikunja      (localhost:3456)
   ├── status.andreweigel.me    ──▶  Uptime Kuma  (localhost:3001)
   └── scattered.andreweigel.me ──▶  Scattered    (localhost:3002 / 8001)
```

---

## Services

| Service | URL | Description |
|---|---|---|
| Vaultwarden | vault.andreweigel.me | Password manager (Bitwarden-compatible) |
| Nextcloud | cloud.andreweigel.me | File storage (Google Drive replacement) |
| Immich | photos.andreweigel.me | Photo library (Google Photos replacement) |
| Jellyfin | media.andreweigel.me | Video streaming (movies & TV) |
| Navidrome | music.andreweigel.me | Music streaming (Subsonic API) |
| Audiobookshelf | audiobooks.andreweigel.me | Audiobook & podcast server (chapters, resume, mobile apps) |
| Calibre-Web | books.andreweigel.me | Ebook library with OPDS (Kobo-compatible) |
| Vikunja | do.andreweigel.me | To-do & project management |
| Uptime Kuma | status.andreweigel.me | Uptime monitoring |
| Scattered | scattered.andreweigel.me | Personal task manager with LLM + MCP server |

---

## Infrastructure

| Component | Spec | Cost |
|---|---|---|
| VPS | Hetzner CX32 — 4 vCPU, 8 GB RAM, 80 GB SSD, Nuremberg | ~€15/mo |
| Storage | Hetzner Storage Box BX11 — 1 TB, Falkenstein | ~€4/mo |
| Domain | andreweigel.me at Gandi.net | ~€15/yr |
| **Total** | | **~€19/mo** |

### Storage layout (Hetzner Storage Box)

```
Storage Box (1TB)
├── nextcloud/    User files (Nextcloud external storage)
├── immich/       Photo library
├── jellyfin/
│   ├── movies/
│   └── tvshows/
├── navidrome/      Music library
├── audiobookshelf/ Audiobook library (also exposed in Nextcloud via SFTP)
└── calibre/        Ebook library (Calibre database)
```

---

## Stack

- **OS:** Ubuntu 24.04
- **Reverse proxy:** Nginx + Let's Encrypt (Certbot)
- **Services:** Docker Compose
- **Firewall:** UFW (ports 22, 80, 443 only)
- **Security:** Fail2Ban, SSH key auth only
- **Infrastructure as code:** Pulumi (TypeScript, Hetzner provider)

---

## Quick Start

> Full walkthrough: [docs/setup-guide.md](docs/setup-guide.md)

### 1. Provision the server

```bash
cd infra
npm install
pulumi stack init prod
pulumi config set --secret hcloudToken <your-hetzner-api-token>
pulumi up
```

### 2. Bootstrap the server

```bash
ssh root@<server-ip>
git clone https://github.com/AndreWeigel/personal-cloud.git
cd personal-cloud
sudo ./scripts/bootstrap.sh
```

### 3. Configure secrets

```bash
cp .env.example .env
nano .env   # fill in your real values
```

### 4. Deploy a service

```bash
sudo ./scripts/deploy-service.sh <service-name>
sudo ./scripts/ssl-setup.sh <subdomain.yourdomain.com>
```

---

## Repository Structure

```
personal-cloud/
├── README.md
├── .env.example            # Template — copy to .env, never commit .env
├── .gitignore
├── LICENSE
│
├── infra/                  # Pulumi IaC (Hetzner VPS + firewall)
│   └── index.ts
│
├── services/               # Docker Compose per service
│   ├── vaultwarden/
│   ├── nextcloud/
│   ├── immich/
│   ├── jellyfin/
│   ├── navidrome/
│   ├── audiobookshelf/
│   ├── calibre-web/
│   ├── vikunja/
│   ├── uptime-kuma/
│   └── scattered/
│
├── nginx/                  # Nginx reverse proxy configs (one file per service)
│
├── scripts/                # Setup and maintenance scripts
│   ├── bootstrap.sh        # Initial server setup
│   ├── deploy-service.sh   # Deploy or update a service
│   ├── ssl-setup.sh        # Obtain Let's Encrypt certificate
│   └── backup.sh           # Backup routine
│
└── docs/                   # Detailed documentation
    ├── setup-guide.md
    ├── storage-architecture.md
    ├── security.md
    └── roadmap.md
```

---

## Privacy & Sovereignty

- All infrastructure is in **Germany / EU** (Hetzner Nuremberg + Falkenstein)
- Every service is **open source** — no vendor lock-in
- No data leaves the server (except to the Storage Box, also Hetzner)
- No telemetry, no third-party analytics

---

## License

MIT — see [LICENSE](LICENSE).
