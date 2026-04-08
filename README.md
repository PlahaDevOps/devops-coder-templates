# Coder (local Docker)

```text
Coder/   (devops-coder-templates on GitHub)
  ├── .github/
  │     └── workflows/
  │           ├── pr-check.yml          ← PRs to main: Terraform fmt + validate
  │           └── deploy-template.yml   ← Push to main under coder-templates/** → push template
  ├── docker-compose.yml
  ├── .env                  ← Secrets (gitignored — never commit)
  ├── .env.example
  ├── .gitignore
  ├── coder-data/
  └── coder-templates/
        └── docker-dev/     ← Workspace template (Terraform)
```

## First-time setup

From this folder:

```powershell
cd C:\Users\admin\Desktop\DevOps_work\Coder
copy .env.example .env
# Edit .env per .env.example (OAuth, CODER_ACCESS_URL, Docker TCP if needed)
docker compose up -d
```

**GitHub OAuth apps** — set callback URLs in **GitHub → Settings → Developer settings → OAuth Apps** to match **`CODER_ACCESS_URL`** in `.env` (same host everywhere):

| Purpose | Callback URL pattern |
|--------|----------------------|
| Sign-in (Coder Local app) | `https://YOUR_HOST/api/v2/users/oauth2/github/callback` |
| External auth / Git in workspaces (Coder Local External app) | `https://YOUR_HOST/external-auth/github/callback` |

For local-only dev, use `http://localhost:3000` as the host and matching `http://localhost:3000/...` callbacks.

## Commands

```powershell
docker compose up -d              # Start
docker compose down             # Stop
docker compose restart          # Restart (does not reload .env)
docker compose up -d --force-recreate   # After editing compose or .env
docker compose logs -f          # Logs (Ctrl+C to stop)
```

## Workspace template

See **`coder-templates/docker-dev/README.md`** for Terraform details and `coder create … --template=docker-dev`.

## CI/CD (GitHub Actions)

Workflows use **`runs-on: self-hosted`** (Windows). Install the runner per **`.github/self-hosted-runner.md`**. For deploy, set repository secrets **`CODER_URL`** and **`CODER_TOKEN`**. If Coder runs on the same machine as the runner, **`CODER_URL`** can be `http://localhost:3000`.

| Workflow | When | What |
|----------|------|------|
| **`pr-check.yml`** | Every PR targeting **`main`** | `terraform fmt -check`, `init`, `validate`; optional PR comment |
| **`deploy-template.yml`** | Push to **`main`** changing **`coder-templates/**`** | `coder templates push` for `docker-dev` |

**Secrets** (Settings → Secrets and variables → Actions):

| Secret | Purpose |
|--------|---------|
| `CODER_URL` | Base URL of Coder (reachable from the runner; often same as server `CODER_ACCESS_URL`) |
| `CODER_TOKEN` | Long-lived API token for a user who can **create template versions** |

PR checks do not need these. Deploy needs both.

### Deploy fails with `rbac: forbidden`

The token works for login but the user cannot create template versions. As a Coder **Owner**: grant **Template Admin** or **Owner** to the user that owns **`CODER_TOKEN`**, then `coder login` as that user and run `coder tokens create --name github-actions --lifetime 8760h`, update **`CODER_TOKEN`** in GitHub, re-run the workflow. **`CODER_URL`** must match your deployment (no trailing slash).

### Expose local Coder for cloud Actions (e.g. ngrok)

GitHub-hosted runners cannot reach `http://localhost:3000` on your PC; use a tunnel (ngrok, Cloudflare Tunnel, etc.) so **`CODER_URL`** is a public HTTPS URL.

**Compose:** set **`NGROK_AUTH_TOKEN`**, **`NGROK_DOMAIN`**, and **`CODER_ACCESS_URL=https://…`** in `.env` (see **`.env.example`**), then `docker compose up -d --force-recreate`. Tunnel dashboard: **http://localhost:4040**.

**OAuth:** callbacks must use the **same host** as **`CODER_ACCESS_URL`**.

### ngrok free tier: browser warning vs API clients

Automation (`coder login`, `coder templates push`, Actions) may get an HTML interstitial instead of JSON unless clients send **`ngrok-skip-browser-warning`** (ngrok free). Paid ngrok, Cloudflare Tunnel, or a stable public host avoids this. Quick check:

```bash
curl -sS -o /dev/null -w "%{http_code}\n" -H "ngrok-skip-browser-warning: any" "https://YOUR_HOST/healthz"
```

Expect **200**. Deploy only works while the tunnel is up if **`CODER_URL`** points through it.

---

**Optional:** Branch protection on `main` — require PRs and the **Validate Terraform** check.

**Note:** GitHub Actions [plans to move default Node for actions to 24](https://github.blog/changelog/2025-09-19-deprecation-of-node-20-on-github-actions-runners/) (Node 20 deprecated 2026). Bump action versions when they support Node 24 if needed.
