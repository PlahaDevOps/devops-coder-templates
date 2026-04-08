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

1. Copy `../.env.example` to `../.env` and set **`GITHUB_CLIENT_*`** (OAuth app “Coder Local”, sign-in) and **`GITHUB_EXTERNAL_*`** (OAuth app “Coder Local External”, Git) — see comments in `.env.example` for callback URLs.
2. **Authorization callback URL:** `http://localhost:3000/api/v2/users/oauth2/github/callback`
3. From **`DevOps_work/Coder`**, run:

```bash
docker compose up -d
```

4. Verify: **http://localhost:3000/deployment/userauth**

Day-to-day commands (start, stop, restart, logs, recreating after config edits): see **`../README.md`** in the **Coder** folder.

### Workspace build: `Error pinging Docker` / `docker_volume` / Terraform exit 1

The Coder **server** talks to Docker over **TCP** (`DOCKER_HOST`, default `tcp://host.docker.internal:2375`). In Docker Desktop, enable **Expose daemon on tcp://localhost:2375** (see **`../.env.example`**). Ensure **`coder templates push`** is run after changing `main.tf` so the server uses the template without a hardcoded unix socket.

## CI

Pull requests that change files under `coder-templates/` run **Terraform format check** and **`terraform validate`** (see `.github/workflows/pr-check.yml`). Merging to `main` can run **template deploy** if `CODER_URL` and `CODER_TOKEN` are set in repository secrets.

For a dated session log (merge history, PR test branch, deploy failure exit code 1, Node 20 deprecation warning), see **`../README.md`** → **Session log & CI annotations**.
