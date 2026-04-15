# â”€â”€ Persistent Storage â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

resource "kubernetes_persistent_volume_claim" "home" {
  metadata {
    name      = "coder-${lower(data.coder_workspace.me.id)}-home"
    namespace = local.namespace
    labels = {
      # Standard K8s labels
      "app.kubernetes.io/name"    = "coder-${lower(data.coder_workspace.me.id)}-home"
      "app.kubernetes.io/part-of" = "coder"
      # Coder-specific labels (same pattern as Aven)
      "com.coder.resource"         = "true"
      "com.coder.workspace.id"     = data.coder_workspace.me.id
      "com.coder.workspace.name"   = data.coder_workspace.me.name
      "com.coder.template.id"      = data.coder_workspace.me.template_id
      "com.coder.template.name"    = data.coder_workspace.me.template_name
      "com.coder.template.version" = data.coder_workspace.me.template_version
      "com.coder.user.id"          = data.coder_workspace_owner.me.id
      "com.coder.user.username"    = data.coder_workspace_owner.me.name
    }
    annotations = {
      "com.coder.user.email" = data.coder_workspace_owner.me.email
    }
  }
  wait_until_bound = false
  spec {
    access_modes = ["ReadWriteOnce"]
    resources {
      requests = {
        storage = local.chosen_profile.storage
      }
    }
  }
}

# â”€â”€ Kubernetes Pod â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

resource "kubernetes_pod" "workspace" {
  count = data.coder_workspace.me.start_count

  metadata {
    name      = "coder-${lower(data.coder_workspace.me.id)}"
    namespace = local.namespace
    labels = {
      "app.kubernetes.io/name"     = "coder-workspace"
      "app.kubernetes.io/part-of"  = "coder"
      "com.coder.resource"         = "true"
      "com.coder.workspace.id"     = data.coder_workspace.me.id
      "com.coder.workspace.name"   = data.coder_workspace.me.name
      "com.coder.template.id"      = data.coder_workspace.me.template_id
      "com.coder.template.name"    = data.coder_workspace.me.template_name
      "com.coder.template.version" = data.coder_workspace.me.template_version
      "com.coder.user.id"          = data.coder_workspace_owner.me.id
      "com.coder.user.username"    = data.coder_workspace_owner.me.name
      "com.coder.profile"          = data.coder_parameter.workspace_profile.value
    }
    annotations = {
      "com.coder.user.email" = data.coder_workspace_owner.me.email
    }
  }

  spec {
    service_account_name = "coder"

    security_context {
      fs_group = 1000
    }

    container {
      name              = "dev"
      image             = "codercom/enterprise-base:ubuntu"
      image_pull_policy = "Always"
      # init_script embeds localhost for agent download — see locals.pod_agent_command (Docker vs AWS).
      command = ["sh", "-c", local.pod_agent_command]

      security_context {
        run_as_user = 1000
      }

      env {
        name  = "CODER_AGENT_TOKEN"
        value = coder_agent.main.token
      }

      env {
        name  = "CODER_AGENT_URL"
        value = local.coder_agent_api_url
      }

      env {
        name  = "CODER_URL"
        value = local.coder_agent_api_url
      }

      # Avoid corporate/Windows proxy env leaking into child processes (can break Coder ↔ workspace dials).
      env {
        name  = "HTTP_PROXY"
        value = ""
      }

      env {
        name  = "HTTPS_PROXY"
        value = ""
      }

      env {
        name  = "NO_PROXY"
        value = "*"
      }

      # agentapi reads AGENTAPI_* (viper) — iframe / ccw--*.localhost embeds need permissive CORS, not only localhost:*
      env {
        name  = "AGENTAPI_ALLOWED_HOSTS"
        value = "*"
      }

      env {
        name  = "AGENTAPI_ALLOWED_ORIGINS"
        value = "*"
      }

      env {
        name  = "GIT_AUTHOR_NAME"
        value = local.git_author_name
      }

      env {
        name  = "GIT_AUTHOR_EMAIL"
        value = local.git_author_email
      }

      # Anthropic API key — create first: kubectl create secret generic anthropic-api-key --from-literal=api-key=YOUR_KEY -n coder-workspaces
      env {
        name = "ANTHROPIC_API_KEY"
        value_from {
          secret_key_ref {
            name = "anthropic-api-key"
            key  = "api-key"
          }
        }
      }

      # Claude Code / install.sh expect CLAUDE_API_KEY (same value as Anthropic key)
      env {
        name = "CLAUDE_API_KEY"
        value_from {
          secret_key_ref {
            name = "anthropic-api-key"
            key  = "api-key"
          }
        }
      }

      resources {
        requests = {
          cpu    = local.chosen_profile.cpu_request
          memory = local.chosen_profile.memory_request
        }
        limits = {
          cpu    = local.chosen_profile.cpu_limit
          memory = local.chosen_profile.memory_limit
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
