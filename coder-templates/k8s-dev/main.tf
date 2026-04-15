# Kubernetes-backed Coder workspace template (split across *.tf).
#
# - parameters.tf — workspace profile, repo URL (default: this repo), dotfiles
# - locals.tf    — namespace, Coder access URL for agents (AWS vs Docker Desktop)
# - agent.tf     — coder_agent, dotfiles script, metadata
# - kubernetes.tf — PVC + pod (enterprise-base, Anthropic secret, volumes)
# - modules.tf   — git-clone, git-config, cursor, vscode, jupyterlab, claude-code
# - ai_task.tf   — Coder AI tasks registration
# - coder_env_coder_url.tf — CODER_URL / session token for CLI inside pod

terraform {
  required_providers {
    coder = {
      source  = "coder/coder"
      version = "~> 2.15.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 3.0.1"
    }
  }
}

provider "coder" {}

# In-cluster auth when provisioner runs inside the cluster (typical for Coder k8s workspaces).
provider "kubernetes" {}
