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
