# Scattered

Personal task and goal manager with LLM integration and MCP server.

**Repo:** https://github.com/AndreWeigel/scattered (private)

Managed via its own CI/CD pipeline — pushes to `main` automatically deploy to this server via GitHub Actions. Not managed by `deploy-service.sh`.

## Ports

| Container | Host port |
|-----------|-----------|
| Next.js (web) | 127.0.0.1:3002 |
| FastAPI (api) | 127.0.0.1:8001 |
| PostgreSQL (db) | internal only |

## Manual deploy (if needed)

```bash
cd /root/scattered
git pull origin main
docker compose -f docker-compose.yml up -d --build
docker compose -f docker-compose.yml exec -T api alembic upgrade head
```
