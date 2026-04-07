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

## Coder server: GitHub login (local Docker)

Admin **User Authentication → Login with GitHub** is driven by server env vars, not the UI. For this repo’s helper script:

1. In GitHub: **Settings → Developer settings → OAuth Apps → Coder Local** (or your app).
2. Set **Authorization callback URL** to: `http://localhost:3000/api/v2/users/oauth2/github/callback`
3. **Generate a new client secret** and put **Client ID** and **Client secret** in `coder-github.env` (copy from `coder-github.env.example`; that file is gitignored).
4. From this directory, run: `.\start-coder-github.ps1` (recreates the `coder` container with OAuth).

Without a real client secret in `coder-github.env`, GitHub login stays disabled in Admin Settings.
