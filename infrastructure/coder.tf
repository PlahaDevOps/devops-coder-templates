# ─── Coder Namespace ────────────────────────────────
resource "kubernetes_namespace" "coder" {
  metadata {
    name   = "coder"
    labels = local.common_labels
  }
}

resource "kubernetes_namespace" "coder_workspaces" {
  metadata {
    name   = "coder-workspaces"
    labels = local.common_labels
  }
}

# ─── Coder Secrets ──────────────────────────────────
resource "kubernetes_secret" "coder_github_oauth" {
  metadata {
    name      = "coder-github-oauth"
    namespace = kubernetes_namespace.coder.metadata[0].name
  }

  # Plain strings; provider sends them like stringData (no base64encode() — avoids double encoding)
  data = {
    "client-id"     = var.github_oauth_client_id
    "client-secret" = var.github_oauth_client_secret
  }
}

resource "kubernetes_secret" "anthropic_api_key" {
  metadata {
    name      = "anthropic-api-key"
    namespace = kubernetes_namespace.coder_workspaces.metadata[0].name
  }

  data = {
    "api-key" = var.anthropic_api_key
  }
}

# ─── Coder RBAC ─────────────────────────────────────
# Coder server ServiceAccount (in `coder` ns) needs admin over workspace namespace.
resource "kubernetes_role_binding" "coder_admin" {
  metadata {
    name      = "coder-admin"
    namespace = kubernetes_namespace.coder_workspaces.metadata[0].name
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = "admin"
  }

  subject {
    kind      = "ServiceAccount"
    name      = "coder"
    namespace = kubernetes_namespace.coder.metadata[0].name
  }
}

# ─── Coder Helm Release ─────────────────────────────
resource "helm_release" "coder" {
  repository = "https://helm.coder.com/v2"
  name       = "coder"
  chart      = "coder"
  version    = var.coder_version
  namespace  = kubernetes_namespace.coder.metadata[0].name

  depends_on = [
    kubernetes_namespace.coder,
    kubernetes_secret.coder_github_oauth,
    kubernetes_role_binding.coder_admin,
  ]

  values = [yamlencode({
    coder = {
      env = [
        {
          name  = "CODER_ACCESS_URL"
          value = local.coder_access_url
        },
        {
          name  = "CODER_WILDCARD_ACCESS_URL"
          value = local.coder_wildcard_access_url
        },
        {
          name  = "CODER_EXTERNAL_AUTH_0_ID"
          value = "github"
        },
        {
          name  = "CODER_EXTERNAL_AUTH_0_TYPE"
          value = "github"
        },
        {
          name = "CODER_EXTERNAL_AUTH_0_CLIENT_ID"
          valueFrom = {
            secretKeyRef = {
              name = kubernetes_secret.coder_github_oauth.metadata[0].name
              key  = "client-id"
            }
          }
        },
        {
          name = "CODER_EXTERNAL_AUTH_0_CLIENT_SECRET"
          valueFrom = {
            secretKeyRef = {
              name = kubernetes_secret.coder_github_oauth.metadata[0].name
              key  = "client-secret"
            }
          }
        }
      ]
      service = {
        type = "ClusterIP"
      }
      # Chart defaults are higher (~4Gi); explicit values replace chart defaults entirely.
      # 512Mi is too small and commonly causes OOMKilled / CrashLoopBackOff on the server.
      # If describe/logs still show OOMKilled, raise memory and/or use a larger instance (e.g. t3.medium+).
      resources = {
        requests = {
          cpu    = "500m"
          memory = "512Mi"
        }
        limits = {
          cpu    = "1000m"
          memory = "1024Mi"
        }
      }
    }
  })]
}

# ─── Coder Ingress (Traefik on k3s) ─────────────────
resource "kubernetes_ingress_v1" "coder" {
  metadata {
    name      = "coder-ingress"
    namespace = kubernetes_namespace.coder.metadata[0].name
    annotations = {
      "traefik.ingress.kubernetes.io/router.entrypoints" = "web"
    }
  }

  spec {
    ingress_class_name = "traefik"

    rule {
      host = local.coder_hostname
      http {
        path {
          path      = "/"
          path_type = "Prefix"
          backend {
            service {
              name = "coder"
              port {
                number = 80
              }
            }
          }
        }
      }
    }

    # Workspace app hostnames: *.ip.nip.io
    rule {
      host = "*.${local.base_domain}"
      http {
        path {
          path      = "/"
          path_type = "Prefix"
          backend {
            service {
              name = "coder"
              port {
                number = 80
              }
            }
          }
        }
      }
    }
  }

  depends_on = [helm_release.coder]
}
