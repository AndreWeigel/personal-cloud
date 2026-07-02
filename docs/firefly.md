# Firefly III — N26 analysis, automated import & AI

Self-hosted [Firefly III](https://www.firefly-iii.org/) for cash-flow analysis of an
N26 account, with automated transaction pulls via GoCardless, optional local-AI
auto-categorization, and natural-language querying from Claude Desktop over MCP.

| Piece | URL / where | Purpose |
|---|---|---|
| Firefly III | `finance.yourdomain.com` (localhost:8082) | Budgeting, reports, rules |
| Data Importer | `import.yourdomain.com` (localhost:8084) | Pull N26 transactions (GoCardless) |
| Ollama + Node-RED | localhost only (SSH tunnel) | AI auto-categorization (optional) |
| MCP server | npx on your Mac | Ask Claude about your finances (optional) |

---

## Step 1: Prerequisites

The Firefly stack and the AI add-on share a Docker network so they can talk to
each other. Create it once:

```bash
docker network create finance-net
```

Create DNS A records pointing at the server:

| Record | Type | Value |
|--------|------|-------|
| `finance.yourdomain.com` | A | `<server-ip>` |
| `import.yourdomain.com` | A | `<server-ip>` |

Fill in the Firefly section of `.env` (see [../.env.example](../.env.example)):

```bash
# 32-character APP_KEY and STATIC_CRON_TOKEN
head /dev/urandom | LC_ALL=C tr -dc 'A-Za-z0-9' | head -c 32; echo   # run twice
openssl rand -hex 16                                                  # AUTO_IMPORT_SECRET
```

Set `FIREFLY_DB_PASSWORD` to something strong. Leave `FIREFLY_PAT` **blank for
now** — you'll generate it after first login. You'll fill in `NORDIGEN_ID` /
`NORDIGEN_KEY` in Step 3.

> ⚠️ Set `FIREFLY_APP_KEY` and `FIREFLY_DB_PASSWORD` **before the first start**.
> The database volume is initialised on first run and locks in the password.

---

## Step 2: Deploy Firefly III

The Data Importer has no built-in login, so its vhost is protected with HTTP
Basic Auth. Create the password file **before** deploying (otherwise
`nginx -t` fails when it can't find the file):

```bash
sudo apt install -y apache2-utils          # provides htpasswd, if missing
sudo htpasswd -c /etc/nginx/.htpasswd-firefly-importer andre
```

Then deploy:

```bash
sudo ./scripts/deploy-service.sh firefly
sudo ./scripts/ssl-setup.sh finance.yourdomain.com
sudo ./scripts/ssl-setup.sh import.yourdomain.com
```

Watch it come up (first boot runs database migrations — give it a minute):

```bash
docker compose -f ~/firefly/docker-compose.yml logs -f firefly
```

Open `https://finance.yourdomain.com`, register the admin account (use the same
email as `FIREFLY_SITE_OWNER`), and create an **Asset account** for N26.

### Generate the Personal Access Token

In Firefly: **Options → Profile → OAuth → Personal Access Tokens → Create new
token**. It's shown **once** — copy it, paste into `.env` as `FIREFLY_PAT`, then
re-deploy so the importer picks it up:

```bash
sudo ./scripts/deploy-service.sh firefly
```

---

## Step 3: Import N26 via GoCardless

Put your GoCardless Bank Account Data credentials into `.env`
(`NORDIGEN_ID`, `NORDIGEN_KEY`) and re-run `deploy-service.sh firefly`.

> GoCardless has closed new registration for its free Bank Account Data service,
> so this path only works with credentials you already hold. If they lapse, fall
> back to CSV: export from N26 and upload the file in the same importer UI.

1. Open `https://import.yourdomain.com`.
2. Choose **GoCardless (Nordigen)** → country **Germany** → **N26**.
3. Authenticate with N26 in the popup (PSD2 consent).
4. Map the N26 account to your Firefly asset account, set the date range, run
   the import once interactively to confirm it works.
5. **Download the configuration** (`Download config` button) and save it as
   `~/firefly/data/import/n26.json` on the server — the automated import reuses it.

### Automate the daily pull

GoCardless allows ~4 successful pulls per account per day and bank consent
expires roughly every 90 days, so a single daily run is the sweet spot. Add a
host cron entry (matches how Nextcloud's cron is set up in the setup guide):

```bash
crontab -e
# Pull N26 every night at 22:00
0 22 * * * docker exec firefly-importer php artisan importer:import /import/n26.json
```

> Every ~90 days the N26 consent expires — re-authenticate by repeating the
> interactive flow in Step 3 (the saved config stays valid).

---

## Step 4: Categorization rules

In Firefly, **Rules** auto-categorize transactions on the fly:
**Automation → Rules → Create rule** — e.g. *description contains "REWE" →
set category "Groceries"*. Then set up **Budgets** and use
**Reports → Default financial report** for the recurring monthly analysis.

---

## Step 5 (optional): AI auto-categorization

Ollama + Node-RED suggest a category/budget for transactions the rules miss.

> ⚠️ This VPS has 8 GB RAM shared with Nextcloud, Immich (incl. ML), Jellyfin
> and two databases. Use a **small** model and watch `docker stats`. If memory
> is tight, run Ollama on your Mac instead and point Node-RED at it.

```bash
# Start the add-on (no Nginx config — it has no public endpoint)
cd ~/firefly-ai         # after: sudo cp -r services/firefly-ai ~/firefly-ai
docker compose up -d

# Pull a small model
docker exec firefly-ollama ollama pull llama3.2:3b
```

Edit the Node-RED flow over an SSH tunnel (never expose it publicly):

```bash
ssh -L 1880:localhost:1880 root@<server-ip>
# then open http://localhost:1880 in your browser
```

Build the flow: **http-in** (`/firefly`) → **function** (build prompt from the
transaction) → **http-request** to `http://firefly-ollama:11434/v1/chat/completions`
→ **http-request** back to `http://firefly:8080/api/v1/transactions/...` with header
`Authorization: Bearer <FIREFLY_PAT>` to set the category and an `ai-assisted` tag.

Finally, in Firefly create the webhook: **Automation → Webhooks → Create** —
trigger *after transaction creation*, response *transaction*, delivery *JSON*,
URL `http://firefly-node-red:1880/firefly`.

Walkthrough reference:
<https://blog.php-systems.com/automating-firefly-iii-categorization-with-node-red-and-lightweight-ai/>

---

## Step 6 (optional): Ask Claude about your finances (MCP, local)

Run the [firefly-iii-mcp](https://github.com/etnperlong/firefly-iii-mcp) server
locally on your Mac via `npx` and register it with Claude Desktop — nothing is
deployed on the server. Queries like *"biggest expense categories last month"*
become real API calls.

Add to your Claude Desktop MCP config (`claude_desktop_config.json`):

```json
{
  "mcpServers": {
    "firefly-iii": {
      "command": "npx",
      "args": ["-y", "@firefly-iii-mcp/local"],
      "env": {
        "FIREFLY_III_URL": "https://finance.yourdomain.com",
        "FIREFLY_III_PAT": "<your Personal Access Token>",
        "FIREFLY_III_PRESET": "reporting"
      }
    }
  }
}
```

> - Use a **preset** (`reporting`, `budget`, `default`…), not `full` — 140 tools
>   overwhelms most MCP clients. Start read-mostly with `reporting`.
> - The PAT grants full read/write to your finances. Keep it in the env block
>   (never a URL query param), and remember that querying via a cloud AI sends
>   the returned transaction data to that provider.

---

## Maintenance

```bash
# Update Firefly
cd ~/firefly && docker compose pull && docker compose up -d

# Trigger the importer manually (outside the nightly cron)
docker exec firefly-importer php artisan importer:import /import/n26.json

# Logs
docker compose -f ~/firefly/docker-compose.yml logs -f
```
