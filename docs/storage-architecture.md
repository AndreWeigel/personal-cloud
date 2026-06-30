# Storage Architecture

How data is stored and organised across the personal-cloud stack.

---

## Overview

```
VPS (CX32 — 80 GB SSD, Nuremberg)
│
├── /                         OS + Docker images + service configs
├── ~/nextcloud/data/         Nextcloud app data (not user files)
├── ~/nextcloud/db/           MariaDB database files
├── ~/vaultwarden/data/       Encrypted vault items
├── ~/jellyfin/config/        Jellyfin metadata, config, and DB
├── ~/jellyfin/cache/         Jellyfin transcoding cache
├── ~/navidrome/data/         Navidrome database and playlists
├── ~/audiobookshelf/config/  Audiobookshelf settings, users, sessions
├── ~/audiobookshelf/metadata/ Audiobookshelf covers, caches, backups
│
└── /mnt/storagebox/          ─── sshfs mount ───▶  Hetzner Storage Box (1 TB, Falkenstein)
    ├── nextcloud/                                    Nextcloud user files
    ├── immich/                                       Photo library
    ├── jellyfin/movies/                              Movies (read-only in container)
    ├── jellyfin/tvshows/                             TV shows (read-only in container)
    ├── navidrome/                                    Music library (read-only in container)
    └── audiobookshelf/                               Audiobook library (shared with Nextcloud)
```

---

## VPS SSD (`/` — 80 GB)

Used for:
- OS and system packages
- Docker images
- Service configuration files
- Nextcloud app data (`~/nextcloud/data/`) — internal Nextcloud files, not user uploads
- MariaDB data (`~/nextcloud/db/`)
- Vaultwarden data (`~/vaultwarden/data/`) — the encrypted vault

This fills up over time as Docker images accumulate. Clean up with:
```bash
docker image prune -a
docker system prune
```

---

## Hetzner Storage Box (1 TB)

The Storage Box lives in Falkenstein (FSN1) — a different Hetzner datacenter from the VPS.
It's accessed over SFTP and mounted on the VPS using `sshfs`.

**Why a separate Storage Box?**
- User files (photos, documents, videos) grow much faster than a VPS SSD can handle
- 1 TB for ~€4/mo is much cheaper than upgrading the VPS
- Data is geographically separated from the VPS

**Mount point:** `/mnt/storagebox/nextcloud`

**fstab entry:**
```
uXXXXXX@uXXXXXX.your-storagebox.de:/nextcloud /mnt/storagebox/nextcloud fuse.sshfs defaults,allow_other,reconnect,_netdev 0 0
```

**Nextcloud integration:**
The Storage Box is configured as an SFTP External Storage in Nextcloud's admin panel. User files are stored there while app data stays on the VPS SSD.

---

## Backups

| What | How | Where |
|------|-----|-------|
| VPS disk | Hetzner automatic server backups (weekly snapshots) | Hetzner Cloud |
| Vaultwarden data | `backup.sh` creates `.tar.gz` archives | `/var/backups/personal-cloud/` |
| Nextcloud DB | `backup.sh` stops DB, archives `/db/` | `/var/backups/personal-cloud/` |
| Storage Box files | Hetzner Storage Box has built-in snapshots | Hetzner Storage Box |

The `backup.sh` script (see [../scripts/backup.sh](../scripts/backup.sh)) handles local backups and rotates them after 7 days. For off-site redundancy, consider copying the archives to the Storage Box or a separate location.

---

## Media storage (Jellyfin & Navidrome)

All media is stored on the Storage Box and mounted **read-only** inside the containers. This means:
- A compromised container cannot modify or delete your media files
- The VPS SSD isn't consumed by large video/music libraries
- Jellyfin config and cache (thumbnails, metadata) stay on the fast VPS SSD for performance

To add media, upload files directly to the Storage Box:
```bash
# Via SFTP (port 23)
sftp -P 23 uXXXXXX@uXXXXXX.your-storagebox.de
# Then navigate to /home/jellyfin/movies or /home/navidrome
```

After adding music, trigger a Navidrome scan from its web UI (**Settings → Scan Library**), or wait for the hourly auto-scan. Jellyfin scans automatically when you add a new library item, or you can trigger it manually from the dashboard.

---

## Audiobooks (Audiobookshelf + Nextcloud bridge)

Audiobookshelf stores its library at `/mnt/storagebox/audiobookshelf` (Storage Box
folder `/home/audiobookshelf`), mounted into the container at `/audiobooks`. Its
config and generated metadata stay on the VPS SSD (`~/audiobookshelf/config` and
`~/audiobookshelf/metadata`).

The same Storage Box folder is exposed inside Nextcloud as a second SFTP External
Storage mount (mount point **Audiobooks**, rooted at `/home/audiobookshelf`), a
sibling of the existing `/Storage Box` mount that points at `/home/nextcloud`.
Because both reference the same directory, a book dropped into the Nextcloud
**Audiobooks** folder (e.g. via the desktop sync client) appears in Audiobookshelf,
and vice versa:

```
Nextcloud "Audiobooks"  ──SFTP──┐
                                ├──▶  Storage Box /home/audiobookshelf
Audiobookshelf /audiobooks ─sshfs┘            (same directory)
```

Server-side encryption is disabled, so files written through Nextcloud land as
plaintext and remain directly readable by Audiobookshelf. After uploading, trigger
a scan from the ABS web UI — network mounts don't reliably auto-detect new files.

Recommended layout for clean metadata matching:
```
audiobookshelf/<Author>/<Title>/<audio files (.m4b, .mp3, …)>
```
