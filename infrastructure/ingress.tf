# Traefik ships with k3s. Hostname-based routes are defined per app (see coder.tf).
# Optional: Traefik dashboard — may require matching Service name/port for your k3s version.

resource "kubernetes_ingress_v1" "traefik_dashboard" {
  metadata {
    name      = "traefik-dashboard"
    namespace = "kube-system"
    annotations = {
      "traefik.ingress.kubernetes.io/router.entrypoints" = "web"
    }
  }

  spec {
    ingress_class_name = "traefik"

    rule {
      host = "traefik.${local.base_domain}"
      http {
        path {
          path      = "/"
          path_type = "Prefix"
          backend {
            service {
              name = "traefik"
              port {
                number = 9000
              }
            }
          }
        }
      }
    }
  }
}
