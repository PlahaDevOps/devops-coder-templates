# Self-hosted GitHub Actions runner (Windows)

Use this when you want jobs (especially **Deploy Coder Template**) to run on your own PC so they can reach **Coder on `localhost`** or your LAN without relying on ngrok for GitHub-hosted runners.

## Before you start

1. On the repo: **Settings → Actions → Runners → New self-hosted runner** — choose **Windows** and copy the **`config.cmd`** line (it contains a **one-time registration token**). Do **not** paste that token into issues, chat, or git.
2. Revoke/rotate any token that was exposed elsewhere and generate a new runner registration.

## Install the runner (PowerShell, as Administrator if the docs say so)

Example layout (adjust drive/path as you like):

```powershell
New-Item -ItemType Directory -Force -Path C:\actions-runner | Out-Null
Set-Location C:\actions-runner
```

Download a **current** release from [actions/runner releases](https://github.com/actions/runner/releases) (replace version with the latest `v2.x.x` you want):

```powershell
$v = "2.333.1"   # set to the release you download
$zip = "actions-runner-win-x64-$v.zip"
Invoke-WebRequest -Uri "https://github.com/actions/runner/releases/download/v$v/$zip" -OutFile $zip
Add-Type -AssemblyName System.IO.Compression.FileSystem
[System.IO.Compression.ZipFile]::ExtractToDirectory("$PWD\$zip", "$PWD")
```

Optional: verify the SHA256 from the release page against `(Get-FileHash $zip -Algorithm SHA256).Hash`.

## Configure

From `C:\actions-runner` (use the **exact** `config.cmd` line from GitHub, including your repo URL and **fresh** token):

```powershell
.\config.cmd --url https://github.com/OWNER/REPO --token RUNNER_REGISTRATION_TOKEN
```

Recommended: add labels so workflows can target this machine (example):

```powershell
.\config.cmd --url https://github.com/OWNER/REPO --token RUNNER_REGISTRATION_TOKEN --labels self-hosted,windows,coder
```

## Run

- **Interactive (testing):** `.\run.cmd`
- **Service (recommended):** follow GitHub’s docs to install the runner as a Windows service so it survives logoff/reboot.

## Repo workflows

This repository’s workflows use `runs-on: self-hosted` (see `.github/workflows/`). If you used custom **labels**, set `runs-on: [self-hosted, windows]` or `runs-on: [self-hosted, coder]` to match.

## Notes

- **Template deploy to AWS** uses **`deploy-coder-aws.yml`** on **GitHub-hosted** `ubuntu-latest` (secrets **`AWS_CODER_URL`** / **`AWS_CODER_TOKEN`**). **`deploy-template.yml`** is **manual only** (`workflow_dispatch`) for **local** Coder via this Windows runner (`CODER_URL` / **`CODER_TOKEN`**).
- Keep the runner machine **on** and **network-available** when Actions should run.
- Install **Terraform** is handled by `hashicorp/setup-terraform` in the workflow; **Git** is usually present on developer machines—install [Git for Windows](https://git-scm.com/download/win) if checkout fails.

## Troubleshooting: workflow fails or never starts

| Symptom | What to check |
|--------|----------------|
| Job **Queued** for a long time | No **idle** runner for this repo. **Settings → Actions → Runners** — runner must be **Idle** (green), registered under **this repository** (not only org-level unless you use org runners). Start `run.cmd` or the **Actions Runner** Windows service. |
| Job **fails in ~30–60s** | A runner ran the job. Open the run → expand the failed step. Common issues: **`pwsh` missing** (workflows in this repo use **`powershell`**), **Git missing**, **Coder CLI download blocked**, **`coder login`** failed (wrong **`CODER_URL`** / **`CODER_TOKEN`** / RBAC). |
| **Merge PR** blocked | Branch protection may require passing checks. If **PR Checks** or **Deploy** fail, fix workflows or relax rules. Merging to `main` still works if you have permission and bypass (not recommended without fixing the runner). |
| **`CODER_URL` is `http://localhost:3000`** | The runner process must run **on the same Windows machine** where Coder (Docker) listens on **port 3000**. |

After fixing the runner, **Re-run failed jobs** on the last workflow run (no new commit required).
