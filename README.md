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
  │     └── docker-dev/                 ← Workspace template
  │           ├── main.tf
  │           ├── .terraform.lock.hcl
  │           └── README.md
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
# 1. Copy and edit secrets (OAuth, ngrok, CODER_ACCESS_URL)
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
| `pr-check.yml` | Every **PR to `main`** | `terraform fmt -check`, `init`, `validate`, **tfsec** (soft-fail), PR comments |
| `deploy-template.yml` | **Push to `main`** changing files under **`coder-templates/**`** | `coder templates push` for `docker-dev` |
| `labeler.yml` | PR **opened**, **synchronize**, **reopened** | Labels from `.github/labeler.yml` |

### GitHub secrets (deploy)

| Secret | Purpose |
|--------|---------|
| `CODER_URL` | Coder base URL reachable from the runner (e.g. `http://localhost:3000` if runner and Coder share the same machine) |
| `CODER_TOKEN` | Long-lived token: `coder tokens create --name github-actions --lifetime 8760h` (user must be able to push template versions) |

PR checks do not require these secrets.

## Troubleshooting

| Issue | What to try |
|-------|-------------|
| **Docker / Terraform cannot reach Docker** | Enable TCP in Docker Desktop; ensure `DOCKER_HOST` / compose matches your setup (see `.env.example`). |
| **`rbac: forbidden` on template deploy** | Grant **Template Admin** (or **Owner**) to the Coder user that owns **`CODER_TOKEN`**; recreate token and update the secret. |
| **ngrok browser warning breaks API/CLI** | Prefer **`CODER_URL=http://localhost:3000`** on a self-hosted runner on the same PC, or a stable HTTPS URL without the free-tier interstitial. |
| **Workspace agent / Docker errors** | Confirm Coder server can use Docker over TCP (`host.docker.internal:2375`) as in compose and template docs. |
