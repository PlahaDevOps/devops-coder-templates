locals {
  namespace           = "coder-workspaces"
  deployment_name     = "coder-${lower(data.coder_workspace.me.id)}"
  access_url_raw      = data.coder_workspace.me.access_url
  coder_agent_api_url = trimsuffix(local.access_url_raw, "/")

  # Host:port only (no scheme) — AgentAPI / sed patches (claude-code post_install).
  coder_agent_api_host = replace(replace(local.coder_agent_api_url, "https://", ""), "http://", "")

  # Pod entrypoint: init_script embeds localhost for agent download. Docker Desktop → host.docker.internal;
  # AWS / public access_url → rewrite localhost:3000 to the workspace access URL.
  _agent_init = coder_agent.main.init_script
  pod_agent_command = (
    can(regex("localhost|127\\.0\\.0\\.1", local.access_url_raw)) ? replace(replace(local._agent_init, "127.0.0.1", "host.docker.internal"), "localhost", "host.docker.internal") : replace(replace(local._agent_init, "http://127.0.0.1:3000", local.coder_agent_api_url), "http://localhost:3000", local.coder_agent_api_url)
  )

  # Default clone dir when using Parameter repo_url (git-clone module + startup_script fallback).
  default_repo_dir = "/home/coder/devops-coder-templates"

  # Git config â€” uses full name if available, falls back to username
  git_author_name  = coalesce(data.coder_workspace_owner.me.full_name, data.coder_workspace_owner.me.name)
  git_author_email = data.coder_workspace_owner.me.email

  # Workspace profiles â€” mirrors Aven's pattern but for local K8s
  workspace_profiles = {
    standard = {
      name                  = "Standard"
      description           = "Generalized development profile."
      cpu_request           = "250m"
      cpu_limit             = "1"
      memory_request        = "512Mi"
      memory_limit          = "1Gi"
      storage               = "5Gi"
      preconfigured_modules = ["vscode", "cursor"]
      startup_script_addon  = ""
    }
    large = {
      name                  = "Large"
      description           = "Profile for heavier workloads."
      cpu_request           = "500m"
      cpu_limit             = "2"
      memory_request        = "1Gi"
      memory_limit          = "2Gi"
      storage               = "10Gi"
      preconfigured_modules = ["vscode", "cursor", "jupyterlab"]
      startup_script_addon  = ""
    }
    xlarge = {
      name                  = "XLarge"
      description           = "Profile for data science and ML workloads."
      cpu_request           = "1"
      cpu_limit             = "4"
      memory_request        = "2Gi"
      memory_limit          = "4Gi"
      storage               = "20Gi"
      preconfigured_modules = ["vscode", "cursor", "jupyterlab"]
      startup_script_addon  = <<-EOT
        echo "ðŸ“Š Installing data science libraries..."
        pip install pandas numpy matplotlib scikit-learn jupyter 2>/dev/null || true
      EOT
    }
  }

  chosen_profile = local.workspace_profiles[data.coder_parameter.workspace_profile.value]
}

# â”€â”€ Data Sources â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

data "coder_provisioner" "me" {}
data "coder_workspace" "me" {}
data "coder_workspace_owner" "me" {}

# Uncomment with github-upload-public-key in modules.tf
# data "coder_external_auth" "github" {
#   id = "github"
# }
