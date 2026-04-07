# Coder (local Docker)

```text
Coder/
  ├── docker-compose.yml    ← Coder server config
  ├── .env                  ← Secrets (gitignored — never commit)
  ├── .env.example          ← Copy to .env
  ├── .gitignore
  ├── coder-data/           ← Coder database / state (created by Docker)
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

| Purpose | URL |
|--------|-----|
| Sign-in (Coder login) | `http://localhost:3000/api/v2/users/oauth2/github/callback` |
| External auth (Git repos in workspaces) | `http://localhost:3000/external-auth/github/callback` |

Use the same OAuth app if GitHub allows multiple callback URLs; otherwise create a second OAuth app for external auth with the second URL. `docker-compose.yml` maps `CODER_EXTERNAL_AUTH_0_*` so workspaces can use Git over HTTPS with `repo` / `read:org` scopes.

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
