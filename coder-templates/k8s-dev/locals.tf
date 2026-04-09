locals {
  namespace       = "coder-workspaces"
  deployment_name = "coder-${lower(data.coder_workspace.me.id)}"

  # Git config — uses full name if available, falls back to username
  git_author_name  = coalesce(data.coder_workspace_owner.me.full_name, data.coder_workspace_owner.me.name)
  git_author_email = data.coder_workspace_owner.me.email

  # Workspace profiles — mirrors Aven's pattern but for local K8s
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
        echo "📊 Installing data science libraries..."
        pip install pandas numpy matplotlib scikit-learn jupyter 2>/dev/null || true
      EOT
    }
  }

  chosen_profile = local.workspace_profiles[data.coder_parameter.workspace_profile.value]
}

# ── Data Sources ─────────────────────────────────────────────

data "coder_provisioner" "me" {}
data "coder_workspace" "me" {}
data "coder_workspace_owner" "me" {}

data "coder_external_auth" "github" {
  id = "github"
}
