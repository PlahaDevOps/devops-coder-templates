# n8n — enable with n8n_enabled = true in terraform.tfvars
# Verify chart/repo (OCI path and values) before enabling in production.

resource "kubernetes_namespace" "n8n" {
  count = var.n8n_enabled ? 1 : 0

  metadata {
    name   = "n8n"
    labels = local.common_labels
  }
}

resource "helm_release" "n8n" {
  count = var.n8n_enabled ? 1 : 0

  # Community chart: https://community-charts.github.io/helm-charts
  name       = "n8n"
  repository = "https://community-charts.github.io/helm-charts"
  chart      = "n8n"
  namespace  = kubernetes_namespace.n8n[0].metadata[0].name

  values = [yamlencode({
    n8n = {
      encryption_key = "change-me-to-random-string"
    }
    service = {
      type = "ClusterIP"
    }
  })]
}

resource "kubernetes_ingress_v1" "n8n" {
  count = var.n8n_enabled ? 1 : 0

  metadata {
    name      = "n8n-ingress"
    namespace = kubernetes_namespace.n8n[0].metadata[0].name
    annotations = {
      "traefik.ingress.kubernetes.io/router.entrypoints" = "web"
    }
  }

  spec {
    ingress_class_name = "traefik"

    rule {
      host = local.n8n_hostname
      http {
        path {
          path      = "/"
          path_type = "Prefix"
          backend {
            service {
              name = "n8n"
              port {
                number = 5678
              }
            }
          }
        }
      }
    }
  }

  depends_on = [helm_release.n8n]
}
