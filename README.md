<<<<<<< HEAD
# Coder (local Docker)

```text
Coder/   (devops-coder-templates on GitHub)
  ├── .github/
  │     └── workflows/
  │           ├── pr-check.yml          ← PR: Terraform fmt + validate
  │           └── deploy-template.yml   ← main: push template to Coder
  ├── docker-compose.yml
  ├── .env                  ← Secrets (gitignored — never commit)
  ├── .env.example
  ├── .gitignore
  ├── coder-data/
  └── coder-templates/
        └── docker-dev/     ← Workspace template (Terraform)
```

## First-time setup

From **`Coder`** (this folder):

```powershell
cd C:\Users\admin\Desktop\DevOps_work\Coder
copy .env.example .env
# Edit .env: GITHUB_CLIENT_ID and GITHUB_CLIENT_SECRET
docker compose up -d
```

**GitHub OAuth app — callback URLs**

Set these in **GitHub** (not in this repo): **Settings → Developer settings → OAuth Apps →** your app (e.g. Coder Local).

| Field | Value |
|--------|--------|
| **Authorization callback URL** (sign-in) | `https://dede-unjumbled-overtruthfully.ngrok-free.dev/api/v2/users/oauth2/github/callback` |

If GitHub allows **multiple** callback URLs on the same app, also add:

| Purpose | URL |
|--------|-----|
| External auth (Git in workspaces) | `https://dede-unjumbled-overtruthfully.ngrok-free.dev/external-auth/github/callback` |

`CODER_ACCESS_URL` in `.env` must use the **same host** as these URLs. For local-only dev without ngrok, use `http://localhost:3000` and matching localhost callbacks instead.

## Commands going forward

Run these from **`Coder`** (where `docker-compose.yml` lives):

```powershell
# Start Coder
docker compose up -d

# Stop Coder
docker compose down

# Restart Coder (same config; does not reload .env changes)
docker compose restart

# Apply changes after editing docker-compose.yml or .env
docker compose up -d --force-recreate

# View logs
docker compose logs -f
```

Press **Ctrl+C** to stop following logs.

## Adding new features later

Edit **`docker-compose.yml`** or **`.env`**, then apply:

```powershell
docker compose up -d --force-recreate
```

You do not need `docker rm -f coder` each time — Compose recreates the service from your updated files.

## Workspace template (`docker-dev`)

See **`coder-templates/docker-dev/README.md`** for the Terraform template and `coder create … --template=docker-dev`.

## CI/CD (GitHub Actions)

| Workflow | When | What |
|----------|------|------|
| **`pr-check.yml`** | PR to `main` touching `coder-templates/**` | `terraform fmt -check`, `init`, `validate`; posts a comment on the PR |
| **`deploy-template.yml`** | Push to `main` touching `coder-templates/**` | Installs Coder CLI, logs in, runs `coder templates push docker-dev` |

**Repository secrets** (Settings → Secrets and variables → Actions):

| Secret | Purpose |
|--------|---------|
| `CODER_URL` | Your Coder deployment URL (must be reachable from GitHub runners, e.g. a public or tunneled URL) |
| `CODER_TOKEN` | API token from `coder tokens create github-actions` (or similar) |

PR checks do not need these secrets. Deploy fails until both are set.

**Branch protection (optional):** On `main`, require PRs, require the **Validate Terraform** check, and require review before merge.

### Expose local Coder with ngrok (GitHub Actions → your laptop)

GitHub Actions runs in the cloud, so **`CODER_URL`** cannot be `http://localhost:3000`. **ngrok** gives a public HTTPS URL that tunnels to Coder.

```text
GitHub Actions (deploy-template.yml)
    → https://YOUR_DOMAIN.ngrok-free.app
        → ngrok (Docker or CLI) → localhost:3000 → Coder
```

**A) ngrok in Docker Compose** (stable URL with a **reserved static domain** in the [ngrok dashboard](https://dashboard.ngrok.com/domains))

1. Copy **`.env.example`** → **`.env`**. Set **`NGROK_AUTH_TOKEN`** (same value as `ngrok config add-authtoken …`), **`NGROK_DOMAIN`** (hostname only), and **`CODER_ACCESS_URL=https://…`** (must match that host).
2. CLI (optional, same token as `.env`): `ngrok config add-authtoken YOUR_TOKEN`
3. Start **ngrok** then **Coder** (`coder` depends on `ngrok` in `docker-compose.yml`):

```powershell
cd C:\Users\admin\Desktop\DevOps_work\Coder
docker compose up -d --force-recreate
```

4. Tunnel UI: **http://localhost:4040**

**B) Alternative: ngrok CLI** (no Compose service): `winget install ngrok.ngrok`, then `ngrok config add-authtoken …`, then `ngrok http http://localhost:3000`, and set **`CODER_ACCESS_URL`** to the forwarding URL.

**GitHub OAuth app** — Callbacks must use the **same host** as **`CODER_ACCESS_URL`**:

| Callback | URL pattern |
|----------|-------------|
| Login | `https://YOUR_HOST/api/v2/users/oauth2/github/callback` |
| External auth | `https://YOUR_HOST/external-auth/github/callback` |

**GitHub Actions secrets**

| Secret | Value |
|--------|--------|
| `CODER_URL` | Same base URL as **`CODER_ACCESS_URL`** (e.g. `https://abc-xyz.ngrok-free.app`) |
| `CODER_TOKEN` | `coder tokens create github-actions` after `coder login` to that URL |

**Operational notes**

- The **deploy** job only succeeds if your tunnel is **up** when the workflow runs (PC on, Docker running, ngrok container or CLI running).
- A **reserved** ngrok domain stays the same across restarts; ephemeral URLs change each time — then update **`.env`**, OAuth, and **`CODER_URL`**.
=======
# Docker Dev Template

A Coder workspace template that creates an Ubuntu Docker container with:
- Git
- Curl
- Wget
- Cursor IDE support

## Usage
```bash
coder create my-workspace --template=docker-dev
```

## Coder server: GitHub OAuth (local Docker)

Admin **User Authentication → Login with GitHub** is configured with **environment variables** when the Coder container starts, not from empty fields in the UI.

### Step 1 — GitHub OAuth app

1. GitHub: **Settings → Developer settings → OAuth Apps** (create or open your app, e.g. **Coder Local**).
2. **Authorization callback URL:** `http://localhost:3000/api/v2/users/oauth2/github/callback`
3. Copy the **Client ID** and generate a **Client secret** (GitHub shows the secret only once).

### Step 2 — Recreate Coder with GitHub OAuth

**Option A — Helper script (recommended)**  
1. Copy `coder-github.env.example` to `coder-github.env` (gitignored).  
2. Set `CODER_OAUTH2_GITHUB_CLIENT_ID` and `CODER_OAUTH2_GITHUB_CLIENT_SECRET` to your real values.  
3. From this directory in PowerShell:

```powershell
.\start-coder-github.ps1
```

**Option B — Manual `docker run`**  
Once you have Client ID and Secret, run:

```powershell
docker rm -f coder

docker run -d --name coder --restart unless-stopped `
  -e CODER_ACCESS_URL="http://localhost:3000" `
  -e CODER_HTTP_ADDRESS="0.0.0.0:3000" `
  -e CODER_OAUTH2_GITHUB_CLIENT_ID="PASTE_CLIENT_ID_HERE" `
  -e CODER_OAUTH2_GITHUB_CLIENT_SECRET="PASTE_CLIENT_SECRET_HERE" `
  -e CODER_OAUTH2_GITHUB_ALLOW_SIGNUPS="true" `
  -v /var/run/docker.sock:/var/run/docker.sock `
  -v "C:/Users/admin/Desktop/DevOps_work/Coder/coder-data:/home/coder/.config" `
  --privileged `
  -p 3000:3000 `
  ghcr.io/coder/coder:latest
```

Replace `PASTE_CLIENT_ID_HERE` and `PASTE_CLIENT_SECRET_HERE` with your GitHub OAuth values.

### Step 3 — Verify

After the container is running, open:

**http://localhost:3000/deployment/userauth**

Confirm **Login with GitHub** is enabled (not **Disabled**).
>>>>>>> 1b577973ed8bf226ebc310a08be2ce6f76a82405
