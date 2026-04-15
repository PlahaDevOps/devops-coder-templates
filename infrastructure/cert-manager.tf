# Let's Encrypt TLS via cert-manager (optional — set enable_tls = true and acme_email in terraform.tfvars).
# Requires EC2 security group to allow inbound TCP 443 to the instance.
#
# ClusterIssuer is applied with kubectl (not kubernetes_manifest) because the Kubernetes
# provider validates CRDs at plan time; kubectl apply only needs them at apply time.
#
# Upgrading from kubernetes_manifest: terraform state rm 'kubernetes_manifest.clusterissuer_letsencrypt[0]'

locals {
  clusterissuer_letsencrypt_yaml = <<-YAML
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-prod
spec:
  acme:
    email: ${var.acme_email}
    server: ${var.acme_use_staging ? "https://acme-staging-v02.api.letsencrypt.org/directory" : "https://acme-v02.api.letsencrypt.org/directory"}
    privateKeySecretRef:
      name: letsencrypt-prod-account-key
    solvers:
      - http01:
          ingress:
            ingressClassName: traefik
YAML
}

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

# Helm returns before the API always serves new CRDs; without this, kubectl can race.
resource "time_sleep" "wait_cert_manager_crds" {
  count = local.tls_enabled ? 1 : 0

  depends_on      = [helm_release.cert_manager[0]]
  create_duration = "90s"
}

resource "null_resource" "clusterissuer_letsencrypt" {
  count = local.tls_enabled ? 1 : 0

  depends_on = [time_sleep.wait_cert_manager_crds[0]]

  triggers = {
    yaml_sha        = sha256(local.clusterissuer_letsencrypt_yaml)
    kubeconfig_path = var.kubeconfig_path
  }

  provisioner "local-exec" {
    command = <<-EOT
set -e
printf '%s' '${base64encode(local.clusterissuer_letsencrypt_yaml)}' | base64 -d | kubectl apply --kubeconfig=${var.kubeconfig_path} -f -
EOT
  }

  provisioner "local-exec" {
    when    = destroy
    command = "kubectl --kubeconfig=${self.triggers.kubeconfig_path} delete clusterissuer letsencrypt-prod --ignore-not-found"
  }
}
