# AGENTS.md

Single instruction file for **humans and all AI / automation** in this repository (IDE agents, PR bots, and CI). Tools should read this file—especially **Review guidelines** and **AI tools & bots**—before suggesting or applying changes.

## Project overview

Coder **workspace templates** in **Terraform**, deployed against **k3s/Kubernetes on AWS EC2** (e.g. Ubuntu 24.04, t3.small).

| Area | Path |
|------|------|
| Docker-based template | `coder-templates/docker-dev/` |
| Kubernetes-based template | `coder-templates/k8s-dev/` |

Each template has its own `main.tf` and related Terraform files. Templates use the **Coder** Terraform provider; keep provider versions pinned.

### Working directory (Coder workspaces)

`/home/coder/devops-coder-templates` — align paths with this layout when generating commands or docs.

### Repository structure

Layout at a glance (workflows match this repo):

```text
├── AGENTS.md                     ← This file (single source of truth)
├── CLAUDE.md                     ← Pointer to AGENTS.md
├── coder-templates/
│   ├── AGENTS.md                 ← Stub; redirects to root AGENTS.md
│   ├── docker-dev/
│   │   └── main.tf               (+ other Terraform files)
│   └── k8s-dev/
│       └── main.tf               (+ other Terraform files)
└── .github/workflows/
    ├── pr-check.yml              ← Terraform fmt/validate + tfsec on PRs
    ├── labeler.yml               ← Auto Label on PRs
    ├── claude-review.yml         ← Claude Code Action + ANTHROPIC_API_KEY
    ├── deploy-coder-aws.yml      ← Push templates to Coder (AWS secrets)
    └── deploy-template.yml       ← Push templates (local/Windows self-hosted)
```

**`coder-templates/AGENTS.md`** is a stub that redirects to this root file.

## AI tools & bots

These integrations use repo context and should follow **Review guidelines** below. Keep secrets in **GitHub Actions secrets** or your cloud provider—never in committed files.

| Tool | Role |
|------|------|
| **ChatGPT Codex Connector** | GitHub App; PR review and `@codex review` style triggers (per Codex settings). Reads this file for review context. |
| **Claude** (Anthropic GitHub App / Chat) | Optional connector; same repo access as configured in GitHub. |
| **Claude Code Review** | GitHub Action: `.github/workflows/claude-review.yml` using `anthropics/claude-code-action` + `ANTHROPIC_API_KEY`. Runs on PRs to `main` and on `@claude` in comments. Review prompt references this file and **`CLAUDE.md`** stub points here. |

**`CLAUDE.md`** at the repo root is a short pointer to this file so Claude-specific tooling that expects `CLAUDE.md` still lands on the same rules.

### Triggering reviews manually

Quick reference (exact phrasing can vary; see each product’s docs):

- **Codex:** comment `@codex review` on the PR (or rely on auto-review when a PR is opened for review, per Codex settings).  
- **Claude:** comment with `@claude` on the PR—for example `@claude review this PR`—or rely on the **Claude Code Review** workflow when a PR targets `main` (`opened` / `synchronize`).

### Assistant behavior (all tools)

- Prefer small, focused changes; match existing style and abstractions.  
- Always explain non-trivial edits.  
- Ask before destructive or irreversible operations.  
- Follow DevOps best practices and treat security as non-negotiable.

## Build & validate

- Run `terraform fmt -check` (use `terraform fmt -recursive` to fix) under each template directory as needed.  
- Run `terraform validate` in each template directory; for CI-style checks use `terraform init -backend=false` first.  
- GitHub Actions also run validation—see `.github/workflows/`.

## Conventions

- **snake_case** for Terraform resources and variables.  
- Include **descriptions** for all variables; use sensible **defaults** where appropriate.  
- **No hardcoded secrets or API keys** — use Kubernetes secrets, Coder variables, or GitHub/CI secrets.  
- Meaningful resource names; prefix with **`coder-`** where it matches existing patterns.  
- Docker images: **pinned tags**, not `:latest`.  
- Each template lives in its own directory.

## Review guidelines

Use this for PR review (human or automated):

- Reject or flag **hardcoded credentials** or API keys.  
- Verify **`terraform fmt`** compliance and successful **`terraform validate`**.  
- Ensure **new variables** have descriptions and defaults where applicable.  
- For Kubernetes-related templates, validate **resource limits** for workspace pods where relevant.  
- Ensure Docker images use **specific tags**, not `:latest`.  
- Keep changes easy to review; call out security and reliability impact.

## CI/CD (brief)

- Workflows live under **`.github/workflows/`** (template validation, deploy to Coder via `coder templates push`, optional Windows self-hosted deploy, Claude review, etc.).  
- Do **not** embed secrets in YAML; use **repository secrets** and environment-specific configuration.  
- Deploy paths may use GitHub-hosted runners (`ubuntu-latest`) and/or self-hosted runners as configured.
