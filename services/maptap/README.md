# MapTap Scoreboard

WhatsApp bot that tracks daily [maptap.gg](https://www.maptap.gg) results and serves
a live scoreboard at https://maptap.andreweigel.me.

**Repo:** https://github.com/AndreWeigel/maptap-scoreboard

Compose file lives in that repo (built from source, like `scattered`), so
`deploy-service.sh` only installs the Nginx config here.

## Ports

| Container | Host port |
|-----------|-----------|
| maptap (Node) | 127.0.0.1:3000 |

## Deploy

```bash
git clone https://github.com/AndreWeigel/maptap-scoreboard.git /root/maptap-scoreboard
cd /root/maptap-scoreboard
cp .env.example .env                  # GROUP_ID empty on first run
docker compose up -d --build
docker compose logs -f                # scan the WhatsApp QR here, then copy the group JID into .env
```

Update: `cd /root/maptap-scoreboard && git pull && docker compose up -d --build`

## Notes

- `/root/maptap-scoreboard/data/` holds the SQLite DB **and** the WhatsApp session —
  back it up; deleting it means re-scanning the QR.
- `GET /healthz` returns `{ whatsappConnected, lastMessageAt }` — worth an Uptime Kuma
  keyword check, since the process stays up even if WhatsApp logs the device out.
