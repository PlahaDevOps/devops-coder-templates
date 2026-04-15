# Let's Encrypt TLS via cert-manager (optional — set acme_email in terraform.tfvars).
# Requires EC2 security group to allow inbound TCP 443 to the instance.
#
# If ClusterIssuer fails with "CRD may not be installed", run once:
#   terraform apply -target='helm_release.cert_manager[0]' -target='time_sleep.wait_cert_manager_crds[0]'
# then: terraform apply

resource "helm_release" "cert_manager" {
  count = local.tls_enabled ? 1 : 0

  name             = "cert-manager"
  repository       = "https://charts.jetstack.io"
  chart            = "cert-manager"
  version          = var.cert_manager_version
  namespace        = "cert-manager"
  create_namespace = true
  timeout          = 600
  wait             = true

  set {
    name  = "crds.enabled"
    value = "true"
  }

  set {
    name  = "global.leaderElection.namespace"
    value = "cert-manager"
  }
}

# Helm returns before the API always serves new CRDs; without this, ClusterIssuer apply can race.
resource "time_sleep" "wait_cert_manager_crds" {
  count = local.tls_enabled ? 1 : 0

  depends_on      = [helm_release.cert_manager[0]]
  create_duration = "90s"
}

resource "kubernetes_manifest" "clusterissuer_letsencrypt" {
  count = local.tls_enabled ? 1 : 0

  manifest = {
    apiVersion = "cert-manager.io/v1"
    kind       = "ClusterIssuer"
    metadata = {
      name = "letsencrypt-prod"
    }
    spec = {
      acme = {
        email  = var.acme_email
        server = var.acme_use_staging ? "https://acme-staging-v02.api.letsencrypt.org/directory" : "https://acme-v02.api.letsencrypt.org/directory"
        privateKeySecretRef = {
          name = "letsencrypt-prod-account-key"
        }
        solvers = [
          {
            http01 = {
              ingress = {
                ingressClassName = "traefik"
              }
            }
          }
        ]
      }
    }
  }

  depends_on = [time_sleep.wait_cert_manager_crds[0]]
}
