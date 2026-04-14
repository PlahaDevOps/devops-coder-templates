# CLAUDE.md

Instructions for **Claude** (Claude Code, GitHub integrations, or other Anthropic Claude surfaces) working in this repository. This file mirrors the intent of `AGENTS.md` with project-specific context for Claude.

## Project overview

Coder workspace templates written in **Terraform**, deployed against **k3s/Kubernetes on AWS EC2** (Ubuntu 24.04, e.g. t3.small). Two templates:

- **`coder-templates/docker-dev/`** — Docker-based Coder workspace template  
- **`coder-templates/k8s-dev/`** — Kubernetes-based Coder workspace template  

Each template has its own `main.tf` and related Terraform files.

## Build and validate

- Run `terraform fmt -check` (and `terraform fmt -recursive` to fix) under each template directory as needed.  
- Run `terraform validate` in each template directory after `terraform init -backend=false` for CI-style checks.  
- Templates use the **Coder** Terraform provider; keep provider versions pinned.

## Conventions

- **snake_case** for Terraform resources and variables.  
- Include **descriptions** for all variables; prefer sensible **defaults** where appropriate.  
- **No hardcoded secrets or API keys** — use Kubernetes secrets, Coder variables, or GitHub/CI secrets.  
- Meaningful resource names; prefix with **`coder-`** where it matches existing patterns.  
- Docker images: **pinned tags**, not `:latest`.

## Review guidelines

When reviewing or editing changes (including pull requests):

- Reject or flag hardcoded credentials.  
- Confirm `terraform fmt` compliance and successful `terraform validate`.  
- Ensure new variables have descriptions and defaults where applicable.  
- For Kubernetes templates, check **resource limits** for workspace pods where relevant.  
- Prefer small, focused changes; match existing style and abstractions.

## CI/CD (brief)

GitHub Actions validate templates and push to Coder (`coder templates push`) on relevant branches; workflow definitions live under `.github/workflows/`. Do not embed secrets in YAML—use repository secrets.

## Coordination with AGENTS.md

`AGENTS.md` at the repo root is the shared agent/review guidance file for other tools (e.g. Codex). Keep **Review guidelines** consistent between `AGENTS.md` and this file when you update project rules.
