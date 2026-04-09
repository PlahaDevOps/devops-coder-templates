terraform {
  required_providers {
    coder = {
      source  = "coder/coder"
      version = "~> 2.15.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.30.0"
    }
  }
}

provider "coder" {}

provider "kubernetes" {
  config_path    = "~/.kube/config"
  config_context = "docker-desktop"
}

data "coder_provisioner" "me" {}
data "coder_workspace" "me" {}
data "coder_workspace_owner" "me" {}

locals {
  workspace_name = lower(data.coder_workspace.me.name)
  owner_name     = lower(data.coder_workspace_owner.me.name)
  namespace      = "coder-workspaces"
}

resource "coder_agent" "main" {
  arch = data.coder_provisioner.me.arch
  os   = "linux"

  display_apps {
    vscode                 = true
    web_terminal           = true
    ssh_helper             = true
    port_forwarding_helper = true
    vscode_insiders        = false
  }

  startup_script = <<-EOT
    set -e
    echo "Welcome to your Kubernetes workspace!"
    sudo apt-get update -q
    sudo apt-get install -y git curl wget vim
    echo "Ready!"
  EOT
}

module "cursor" {
  count    = data.coder_workspace.me.start_count
  source   = "registry.coder.com/coder/cursor/coder"
  version  = "1.4.1"
  agent_id = coder_agent.main.id
  folder   = "/home/coder"
}

resource "kubernetes_persistent_volume_claim" "home" {
  metadata {
    name      = "coder-${local.owner_name}-${local.workspace_name}-home"
    namespace = local.namespace
    labels = {
      "app.kubernetes.io/managed-by" = "coder"
      "coder.owner"                  = local.owner_name
      "coder.workspace"              = local.workspace_name
    }
  }
  spec {
    access_modes = ["ReadWriteOnce"]
    resources {
      requests = {
        storage = "5Gi"
      }
    }
  }
  wait_until_bound = false
}

resource "kubernetes_pod" "workspace" {
  count = data.coder_workspace.me.start_count

  metadata {
    name      = "coder-${local.owner_name}-${local.workspace_name}"
    namespace = local.namespace
    labels = {
      "app.kubernetes.io/managed-by" = "coder"
      "coder.owner"                  = local.owner_name
      "coder.workspace"              = local.workspace_name
    }
  }

  spec {
    service_account_name = "coder"

    container {
      name    = "dev"
      image   = "codercom/enterprise-base:ubuntu"
      command = ["sh", "-c", coder_agent.main.init_script]

      security_context {
        run_as_user = 1000
      }

      env {
        name  = "CODER_AGENT_TOKEN"
        value = coder_agent.main.token
      }

      resources {
        requests = {
          cpu    = "250m"
          memory = "512Mi"
        }
        limits = {
          cpu    = "1"
          memory = "1Gi"
        }
      }

      volume_mount {
        mount_path = "/home/coder"
        name       = "home"
        read_only  = false
      }
    }

    volume {
      name = "home"
      persistent_volume_claim {
        claim_name = kubernetes_persistent_volume_claim.home.metadata[0].name
        read_only  = false
      }
    }
  }
}