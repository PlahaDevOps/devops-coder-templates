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

## Coder server (Docker Compose)

The Coder **server** is configured one level up, not in this folder:

```
DevOps_work/Coder/
  ├── docker-compose.yml
  ├── .env                 ← GitHub OAuth (gitignored)
  ├── .env.example
  ├── coder-data/
  └── coder-templates/
        └── docker-dev/    ← this Terraform template
```

1. Copy `../.env.example` to `../.env` and set `GITHUB_CLIENT_ID` and `GITHUB_CLIENT_SECRET` from your GitHub OAuth app.
2. **Authorization callback URL:** `http://localhost:3000/api/v2/users/oauth2/github/callback`
3. From **`DevOps_work/Coder`**, run:

```bash
docker compose up -d
```

4. Verify: **http://localhost:3000/deployment/userauth**

Day-to-day commands (start, stop, restart, logs, recreating after config edits): see **`../README.md`** in the **Coder** folder.

## CI

Pull requests that change files under `coder-templates/` run **Terraform format check** and **`terraform validate`** (see `.github/workflows/pr-check.yml`). Merging to `main` can run **template deploy** if `CODER_URL` and `CODER_TOKEN` are set in repository secrets.
