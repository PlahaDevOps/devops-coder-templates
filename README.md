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
# Edit .env: GITHUB_CLIENT_ID, GITHUB_CLIENT_SECRET, and DOCKER_GROUP (see .env.example — needed for Docker workspaces / Terraform)
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
| `CODER_TOKEN` | Long-lived API token from a user who can **create template versions** (see below) |

PR checks do not need these secrets. Deploy fails until both are set.

**`CODER_TOKEN` must belong to a privileged user.** Pushing a template runs `coder templates push`, which creates a new template version. If login succeeds but the job fails with **`insert template version: unauthorized: rbac: forbidden`**, the token’s user lacks RBAC permission (often **Member**).

### Fix `rbac: forbidden` on deploy (step-by-step)

Do these in order; skip a step only if you already know it is done.

1. **Pick the GitHub Actions user** — Decide which Coder account will own the token (e.g. your **`admin`** user or a dedicated **`github-actions`** user). You must be able to sign in as an **Owner** to change roles.

2. **Grant a site role that can push templates** — As **Owner**, open **Administration → Users** → select that user → assign **Template Admin** or **Owner**. **Member** is not enough to create template versions.

3. **Confirm `CODER_URL` in GitHub** — Repo → **Settings → Secrets and variables → Actions** → **`CODER_URL`** must be the **same base URL** as **`CODER_ACCESS_URL`** in your Coder server (e.g. `https://your-ngrok-host.ngrok-free.dev`, no trailing slash). GitHub’s runners must reach this URL when the workflow runs (tunnel up if you use ngrok).

4. **Create a new long-lived API token as that user** — On your PC, log in to **that same** user and deployment:
   ```powershell
   coder login https://YOUR_CODER_URL
   coder tokens create github-actions --lifetime 8760h
   ```
   Use default **`all`** scope unless you have a documented minimal scope set that includes template create/update. **Do not** use a short session token for Actions.

5. **Update the `CODER_TOKEN` secret** — In the same GitHub **Actions** secrets page, paste the new token into **`CODER_TOKEN`** (replace the old value entirely).

6. **Re-run the workflow** — **Actions** → **Deploy Coder Template** → open the failed run → **Re-run failed jobs** (or push a tiny commit to `main` under `coder-templates/**`).

7. **If it still fails** — In Coder, confirm the user from step 2 really shows **Template Admin** / **Owner**. Locally run `coder login` + `coder templates push docker-dev --directory ./coder-templates/docker-dev --yes` with the same token; if that fails, the problem is still role/token, not GitHub.

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

### Session log & CI annotations (pick up next session)

**Repo / git (done)**

- Merged local work with `origin/main` using unrelated histories; cleaned leftover merge conflict markers in root **`README.md`** and **`.gitignore`**, then pushed.
- **`main`** and **`coder-docker-root`** were brought in sync (same tree on GitHub; nothing left to compare for a merge-only PR).
- **`chore/test-github-workflows`** branch: small doc change under **`coder-templates/docker-dev`** to open a PR and exercise **PR Checks** (`terraform fmt -check`, `init`, `validate`, PR comment).

**GitHub Actions — last run observations**

| Kind | Detail |
|------|--------|
| **Error (resolved cause)** | **Deploy template to Coder** failed with **`insert template version: unauthorized: rbac: forbidden`** after successful login. This is **not** a bad URL or dead tunnel — the API token authenticates but the user **cannot create template versions**. Fix: grant **Template Admin** (or **Owner**) to the user that owns **`CODER_TOKEN`**, recreate the token if needed (full **`all`** scope or **`template:*`**), update the GitHub secret, re-run. |
| **Warning** | **Node.js 20 deprecation:** `actions/checkout@v4` (and other actions) still run on Node 20; runners will default to **Node 24** from **2026-06-02**; Node 20 removed **2026-09-16**. See [GitHub changelog](https://github.blog/changelog/2025-09-19-deprecation-of-node-20-on-github-actions-runners/). Mitigation: use newer action versions that support Node 24 when available, or set `FORCE_JAVASCRIPT_ACTIONS_TO_NODE24=true` in the workflow to opt in early. |

**Follow-up**

- After RBAC fix: confirm deploy green on **`main`** (tunnel up if **`CODER_URL`** is not public).
- Optionally bump **`actions/checkout`** (and pin workflow env for Node 24 if needed).
