# Roadmap

Planned services and improvements for the personal-cloud stack.

---

## Currently Live

- [x] **Vaultwarden** — password manager (Bitwarden-compatible)
- [x] **Nextcloud** — file storage, calendar, contacts (Google Drive / Suite replacement)
- [x] **Immich** — photo library (Google Photos replacement)
- [x] **Uptime Kuma** — uptime monitoring with public status page
---

## Planned

### Jellyfin — Media Streaming
- URL: `media.andreweigel.me`
- Self-hosted Netflix / Plex alternative
- Media library stored on Storage Box

### Personal Website
- URL: `andreweigel.me`
- Static site or simple CMS

---

## Infrastructure Improvements

- [ ] Automated off-server backups (copy archives to Storage Box or second location)
- [ ] `unattended-upgrades` for automatic security patches
- [ ] Centralised logging (e.g. Loki + Grafana, or simple log aggregation)
- [ ] Consider Crowdsec alongside or instead of Fail2Ban
- [ ] SSH port restriction to home IP in UFW

---

## Deferred / Under Consideration

- **Gitea / Forgejo** — self-hosted Git (probably not worth it given GitHub is free)
- **Wireguard VPN** — for accessing services without exposing them publicly
- **Second VPS** for high-availability (significant cost increase for a personal setup)
