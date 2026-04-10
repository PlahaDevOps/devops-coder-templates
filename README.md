# DevOps Coder Templates

Local Coder deployment with Docker, GitHub OAuth, and a CI/CD pipeline (Terraform checks, template deploy, PR labels).

## Folder structure

```text
Coder/
  ├── .github/
  │     ├── workflows/
  │     │     ├── pr-check.yml          ← Terraform fmt, validate, tfsec on PRs to main
  │     │     ├── deploy-template.yml   ← Push template when main changes under coder-templates/
  │     │     └── labeler.yml           ← Auto-label PRs
  │     ├── labeler.yml                 ← Label rules
  │     ├── dependabot.yml              ← Dependency updates
  │     └── self-hosted-runner.md       ← Runner setup
  ├── coder-templates/
  │     ├── docker-dev/                 ← Docker workspace template
  │     │     ├── main.tf
  │     │     ├── .terraform.lock.hcl
  │     │     └── README.md
  │     └── k8s-dev/                   ← Kubernetes workspace template (split .tf files)
  ├── docker-compose.yml                ← Coder + ngrok
  ├── .env                              ← Secrets (gitignored)
  ├── .env.example
  └── coder-data/                       ← Local DB/state (gitignored)
```

## Prerequisites

- **Docker Desktop** — TCP API enabled: **Settings → General →** expose daemon on `tcp://localhost:2375` (local dev only).
- **ngrok** account and a **static domain** (used by `docker-compose` for a public URL; fill `NGROK_*` and `CODER_ACCESS_URL` in `.env`).
- **Two GitHub OAuth apps** — see [GitHub OAuth setup](#github-oauth-setup).

## Quick start

From the repository root:

```powershell
# 1. Copy and edit secrets (OAuth, ngrok, CODER_ACCESS_URL; optional ANTHROPIC_API_KEY to silence compose warnings)
copy .env.example .env

# 2. Start Coder and ngrok
docker compose up -d

# 3. Open Coder UI
start http://localhost:3000
```

## GitHub OAuth setup

Create two OAuth apps at [GitHub → Developer settings → OAuth Apps](https://github.com/settings/developers). Callback hosts must match **`CODER_ACCESS_URL`** in `.env`.

| App name | Callback URL |
|----------|----------------|
| Coder Local (sign-in) | `https://YOUR_DOMAIN/api/v2/users/oauth2/github/callback` |
| Coder Local External (Git in workspaces) | `https://YOUR_DOMAIN/external-auth/github/callback` |

Copy **Client ID** and **secret** into `.env` as documented in **`.env.example`**.

## Docker commands

Run from the repository root (where `docker-compose.yml` lives).

```powershell
docker compose up -d                      # Start
docker compose down                       # Stop
docker compose restart                    # Restart (does not reload .env)
docker compose up -d --force-recreate     # Apply changes after editing .env or compose
docker compose logs -f coder              # Logs (Ctrl+C to stop)
```

## Workspace template

See **`coder-templates/docker-dev/README.md`** for Terraform details. Common commands:

```powershell
# From repo root — push template to Coder (after coder login)
coder templates push docker-dev --directory ./coder-templates/docker-dev

# Create workspace
coder create my-workspace --template=docker-dev

coder ssh my-workspace
```

## CI/CD

Uses a **self-hosted Windows runner**. Install and register it using **`.github/self-hosted-runner.md`**.

| Workflow | When | What |
|----------|------|------|
| `pr-check.yml` | Every **PR to `main`** | Same checks for **`coder-templates/docker-dev`** and **`coder-templates/k8s-dev`** (matrix); PR comments |
| `deploy-template.yml` | **Push to `main`** changing files under **`coder-templates/**`** | `coder templates push` for **`docker-dev`** and **`k8s-dev`** |
| `labeler.yml` | PR **opened**, **synchronize**, **reopened** | Labels from `.github/labeler.yml` |

### GitHub secrets (deploy)

| Secret | Purpose |
|--------|---------|
| `CODER_URL` | Coder base URL reachable from the runner (e.g. `http://localhost:3000` if runner and Coder share the same machine) |
| `CODER_TOKEN` | Long-lived token: `coder tokens create --name github-actions --lifetime 8760h` (user must be able to push template versions) |

PR checks do not require these secrets.

## Embedded workspace apps on Windows

Coder may open apps on hosts like `http://ccw--<user>--<workspace>.localhost:3000`. **`CODER_WILDCARD_ACCESS_URL`** (e.g. `*.localhost:3000`) is correct on the server, but **Windows does not resolve arbitrary `*.localhost` in the browser** the way many Linux setups do. If the embedded app never loads, either:

- **Hosts file (Administrator PowerShell):** add a line per workspace app host, e.g. `127.0.0.1 ccw--admin--Ai-wspace.localhost` (match the exact hostname from the broken URL), or  
- **Local DNS** such as [Acrylic](https://mayakron.com/alternate-dns-proxy/) — on some systems: `winget install AcrylicDNS` — to handle wildcard `*.localhost` on your machine.

You can still use **Terminal** in the workspace for Claude / Tasks output if the iframe URL fails to resolve.

## Troubleshooting

| Issue | What to try |
|-------|-------------|
| **Compose warns `ANTHROPIC_API_KEY` not set** | Add `ANTHROPIC_API_KEY=` in `.env` (value optional for the server; k8s-dev pods use the `anthropic-api-key` secret). |
| **Embedded app / Claude button URL does not load (Windows)** | See [Embedded workspace apps on Windows](#embedded-workspace-apps-on-windows). |
| **Heartbeat / websocket ping errors in `coder` logs** | Often **ngrok** or idle clients closing the tunnel; usually not fatal. Prefer stable access (e.g. `localhost` for same-machine CLI). |
| **Docker / Terraform cannot reach Docker** | Enable TCP in Docker Desktop; ensure `DOCKER_HOST` / compose matches your setup (see `.env.example`). |
| **`rbac: forbidden` on template deploy** | Grant **Template Admin** (or **Owner**) to the Coder user that owns **`CODER_TOKEN`**; recreate token and update the secret. |
| **ngrok browser warning breaks API/CLI** | Prefer **`CODER_URL=http://localhost:3000`** on a self-hosted runner on the same PC, or a stable HTTPS URL without the free-tier interstitial. |
| **Workspace agent / Docker errors** | Confirm Coder server can use Docker over TCP (`host.docker.internal:2375`) as in compose and template docs. |
