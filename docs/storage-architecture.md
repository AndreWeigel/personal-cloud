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
│
└── /mnt/storagebox/          ─── sshfs mount ───▶  Hetzner Storage Box (1 TB, Falkenstein)
    └── nextcloud/                                    Nextcloud user files (photos, docs, etc.)
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

## Future: Immich (Photo Storage)

When Immich is deployed, its upload directory will be pointed at `/mnt/storagebox/immich` — keeping large photo libraries off the VPS SSD entirely.
