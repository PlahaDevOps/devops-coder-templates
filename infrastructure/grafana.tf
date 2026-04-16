# Grafana — enable with grafana_enabled = true in terraform.tfvars

resource "kubernetes_namespace" "grafana" {
  count = var.grafana_enabled ? 1 : 0

  metadata {
    name   = "grafana"
    labels = local.common_labels
  }
}

resource "helm_release" "grafana" {
  count = var.grafana_enabled ? 1 : 0

  name       = "grafana"
  repository = "https://grafana.github.io/helm-charts"
  chart      = "grafana"
  namespace  = kubernetes_namespace.grafana[0].metadata[0].name

  values = [yamlencode({
    assertNoLeakedSecrets = false
    adminPassword         = var.grafana_admin_password
    service = {
      type = "ClusterIP"
    }
    persistence = {
      enabled = true
      size    = "1Gi"
    }
    initChownData = {
      enabled = false
    }
    "grafana.ini" = {
      server = {
        root_url = "http://${local.grafana_hostname}"
      }
      "auth.github" = {
        enabled       = true
        client_id     = var.grafana_github_client_id
        client_secret = var.grafana_github_client_secret
        scopes        = "user:email,read:org"
        auth_url      = "https://github.com/login/oauth/authorize"
        token_url     = "https://github.com/login/oauth/access_token"
        api_url       = "https://api.github.com/user"
        allow_sign_up = true
      }
    }
  })]
}

resource "kubernetes_ingress_v1" "grafana" {
  count = var.grafana_enabled ? 1 : 0

  metadata {
    name      = "grafana-ingress"
    namespace = kubernetes_namespace.grafana[0].metadata[0].name
    annotations = {
      "traefik.ingress.kubernetes.io/router.entrypoints" = "web"
    }
  }

  spec {
    ingress_class_name = "traefik"

    rule {
      host = local.grafana_hostname
      http {
        path {
          path      = "/"
          path_type = "Prefix"
          backend {
            service {
              name = "grafana"
              port {
                number = 80
              }
            }
          }
        }
      }
    }
  }

  depends_on = [helm_release.grafana]
}
