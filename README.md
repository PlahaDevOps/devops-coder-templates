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
- **ngrok** (optional) — `docker-compose` can expose a tunnel; fill `NGROK_*` in `.env` if you use it. **`CODER_ACCESS_URL` is `http://localhost:3000` in compose** so the UI and `*.localhost` apps share one HTTP origin; GitHub OAuth callbacks should use `http://localhost:3000/...`.
- **Two GitHub OAuth apps** — see [GitHub OAuth setup](#github-oauth-setup).

## Quick start

From the repository root:

```powershell
# 1. Copy and edit secrets (OAuth, optional ngrok, optional ANTHROPIC_API_KEY)
copy .env.example .env

# 2. Start Coder and ngrok
docker compose up -d

# 3. Open Coder UI
start http://localhost:3000
```

## GitHub OAuth setup

Create two OAuth apps at [GitHub → Developer settings → OAuth Apps](https://github.com/settings/developers). Callback hosts must match **`http://localhost:3000`** (same as `CODER_ACCESS_URL` in `docker-compose.yml`).

| App name | Callback URL |
|----------|----------------|
| Coder Local (sign-in) | `http://localhost:3000/api/v2/users/oauth2/github/callback` |
| Coder Local External (Git in workspaces) | `http://localhost:3000/external-auth/github/callback` |

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

# List workspaces (not `coder workspaces list`)
coder list

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

With **`CODER_WILDCARD_ACCESS_URL`** (e.g. `*.localhost:3000`), Coder may open Claude Code / AgentAPI on hosts like:

`http://ccw--<segment>--<owner>.localhost:3000`

The middle segment is **not always the workspace name** — for **AI Tasks** it often includes a **task-derived slug** (e.g. `what-is-11-print-31d2`), so **each new task can get a different hostname**. Copy the exact URL from the dashboard or browser address bar.

**Windows** usually does not resolve arbitrary `*.localhost` like many Linux setups. Options:

- **Hosts file (Administrator):** add `127.0.0.1` plus the **full hostname** (no `http://`), one line per host — workable for a fixed app URL, tedious if the task slug changes every time.
- **Local DNS** such as [Acrylic](https://mayakron.com/alternate-dns-proxy/) — e.g. `winget install AcrylicDNS` — so `*.localhost` resolves without editing `hosts` for every task.

You can still use the workspace **Terminal** (or Tasks → Terminal) for Claude output if the embedded iframe URL fails to resolve.

## Troubleshooting

| Issue | What to try |
|-------|-------------|
| **Compose warns `ANTHROPIC_API_KEY` not set** | Add `ANTHROPIC_API_KEY=` in `.env` (value optional for the server; k8s-dev pods use the `anthropic-api-key` secret). |
| **Embedded app / Claude button URL does not load (Windows)** | See [Embedded workspace apps on Windows](#embedded-workspace-apps-on-windows); use the **exact** hostname Coder shows (task slugs change per AI task). |
| **`coder workspaces list` unrecognized** | Use **`coder list`** (Coder v2 CLI). |
| **Heartbeat / websocket ping errors in `coder` logs** | Often **ngrok** or idle clients closing the tunnel; usually not fatal. Prefer stable access (e.g. `localhost` for same-machine CLI). |
| **Docker / Terraform cannot reach Docker** | Enable TCP in Docker Desktop; ensure `DOCKER_HOST` / compose matches your setup (see `.env.example`). |
| **`rbac: forbidden` on template deploy** | Grant **Template Admin** (or **Owner**) to the Coder user that owns **`CODER_TOKEN`**; recreate token and update the secret. |
| **ngrok browser warning breaks API/CLI** | Prefer **`CODER_URL=http://localhost:3000`** on a self-hosted runner on the same PC, or a stable HTTPS URL without the free-tier interstitial. |
| **Workspace agent / Docker errors** | Confirm Coder server can use Docker over TCP (`host.docker.internal:2375`) as in compose and template docs. |
| **Tasks stuck on “Initializing” / “Agent is connecting” (k8s-dev)** | The agent init script must download the binary from the host, not `localhost` inside the pod. **`k8s-dev`** patches `init_script` like **docker-dev** (`host.docker.internal`). Push the latest template and **rebuild** the workspace. |
| **Claude / AgentAPI “token invalid”, then 502 to port 3284** | **`agentapi-start.sh`** must use **`ARG_CODER_HOST=host.docker.internal:3000`**, not `localhost:3000`, so API calls reach Coder on the host. Template patches this in **post_install** and **startup_script**; pod env sets **`AGENTAPI_ALLOWED_*`**. Rebuild the workspace after updating the template. |
| **502 `dial tcp [fd7a:…]:3284: connection refused`** | Coder is proxying to the workspace **tailnet IPv6**; the app may not accept on that path. **`k8s-dev`** uses **`subdomain = false`** for Claude Code (path-based app URL) to avoid that dial. Push template and **rebuild** the workspace. |
