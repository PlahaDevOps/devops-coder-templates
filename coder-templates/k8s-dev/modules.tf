# â”€â”€ Always-on modules â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

# Temporarily disabled â€” needs write:public_key OAuth scope (re-enable after GitHub external-auth re-link).
# module "github-upload-public-key" {
#   count            = data.coder_workspace.me.start_count
#   source           = "registry.coder.com/coder/github-upload-public-key/coder"
#   version          = "1.0.32"
#   agent_id         = coder_agent.main.id
#   external_auth_id = data.coder_external_auth.github.id
# }

# Auto-configures git username and email inside workspace
module "git-config" {
  count                 = data.coder_workspace.me.start_count
  source                = "registry.coder.com/coder/git-config/coder"
  version               = "1.0.33"
  agent_id              = coder_agent.main.id
  allow_username_change = false
  allow_email_change    = false
}

# Auto-clones repo if URL provided
module "git-clone" {
  count    = data.coder_workspace.me.start_count
  source   = "registry.coder.com/coder/git-clone/coder"
  version  = "1.2.3"
  agent_id = coder_agent.main.id
  url      = data.coder_parameter.repo_url.value
  base_dir = "/home/coder"
}

# coder-login sets CODER_URL to access_url (ngrok) — breaks CLI from the pod; use coder_env_coder_url.tf instead.
# module "coder-login" {
#   count    = data.coder_workspace.me.start_count
#   source   = "registry.coder.com/coder/coder-login/coder"
#   version  = "1.1.1"
#   agent_id = coder_agent.main.id
# }

# â”€â”€ Profile-based modules â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

# Cursor IDE â€” enabled for standard+ profiles
module "cursor" {
  count    = data.coder_workspace.me.start_count > 0 ? (contains(local.chosen_profile.preconfigured_modules, "cursor") ? 1 : 0) : 0
  source   = "registry.coder.com/coder/cursor/coder"
  version  = "1.4.1"
  agent_id = coder_agent.main.id
  folder   = local.default_repo_dir
}

# VS Code Desktop â€” enabled for standard+ profiles
module "vscode" {
  count    = data.coder_workspace.me.start_count > 0 ? (contains(local.chosen_profile.preconfigured_modules, "vscode") ? 1 : 0) : 0
  source   = "registry.coder.com/coder/vscode-desktop/coder"
  version  = "1.2.1"
  agent_id = coder_agent.main.id
  folder   = local.default_repo_dir
}

# JupyterLab â€” only enabled for large/xlarge profiles
module "jupyterlab" {
  count    = data.coder_workspace.me.start_count > 0 ? (contains(local.chosen_profile.preconfigured_modules, "jupyterlab") ? 1 : 0) : 0
  source   = "registry.coder.com/coder/jupyterlab/coder"
  version  = "1.2.2"
  agent_id = coder_agent.main.id
  config = jsonencode({
    ServerApp = {
      tornado_settings = {
        headers = {
          "Content-Security-Policy" = "frame-ancestors 'self' ${data.coder_workspace.me.access_url}"
        }
      }
      root_dir = local.default_repo_dir
    }
  })
}

# Claude Code AI Agent - requires ANTHROPIC_API_KEY / CLAUDE_API_KEY on the pod (kubernetes.tf) and Secret anthropic-api-key.
# Registry module 4.7.5 has no coder_host var; ARG_CODER_HOST is derived from access_url. Use local.coder_agent_api_url via coder_env_coder_url.tf (CODER_URL) instead of ngrok.
# There is no `slug` argument — the child agentapi module already uses web_app_slug "ccw" (see registry claude-code locals.app_slug).
# subdomain=true uses Coder HTTP proxy → tailnet IPv6 (fd7a:…:port). If AgentAPI listens only on loopback or IPv4/v6
# mismatch, you get 502 "connection refused" (see coder/coder#12790). subdomain=false uses path-based app URLs via the
# agent stream — more reliable on Docker Desktop K8s + *.localhost.

module "claude_code" {
  count     = data.coder_workspace.me.start_count
  source    = "registry.coder.com/coder/claude-code/coder"
  version   = "5.0.0"
  agent_id  = coder_agent.main.id
  workdir   = "/home/coder/devops-coder-templates"
  subdomain = false

  # Runs after install.sh writes agentapi-start.sh: patch ARG_CODER_HOST (Terraform embeds access_url/ngrok)
  # and persist CLAUDE_API_KEY into ~/.claude.json for the CLI.
  post_install_script = <<-EOT
#!/bin/bash
set -euo pipefail
_AGENTAPI_START="$$HOME/.claude-module/scripts/agentapi-start.sh"
if [ -f "$$_AGENTAPI_START" ]; then
  sed -i "s|ARG_CODER_HOST='[^']*'|ARG_CODER_HOST='${local.coder_agent_api_host}'|g" "$$_AGENTAPI_START"
  sed -i "s|ARG_CODER_HOST='localhost:3000'|ARG_CODER_HOST='${local.coder_agent_api_host}'|g" "$$_AGENTAPI_START"
  sed -i 's|ARG_CODER_HOST="localhost:3000"|ARG_CODER_HOST="${local.coder_agent_api_host}"|g' "$$_AGENTAPI_START"
  echo "[claude_code post_install] Patched ARG_CODER_HOST to ${local.coder_agent_api_host}"
fi
if [ -n "$$CLAUDE_API_KEY" ] && command -v jq >/dev/null 2>&1; then
  _cf="$$HOME/.claude.json"
  mkdir -p "$$HOME/.claude"
  if [ -f "$$_cf" ]; then
    jq --arg k "$$CLAUDE_API_KEY" '. + {primaryApiKey: $$k, hasCompletedOnboarding: true, autoUpdaterStatus: "disabled"}' "$$_cf" > /tmp/.claude.json.tmp && mv /tmp/.claude.json.tmp "$$_cf"
  else
    jq -n --arg k "$$CLAUDE_API_KEY" '{primaryApiKey: $$k, hasCompletedOnboarding: true, autoUpdaterStatus: "disabled"}' > "$$_cf"
  fi
  echo "[claude_code post_install] Ensured primaryApiKey in ~/.claude.json"
fi
EOT
}
