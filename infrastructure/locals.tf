locals {
  # If no domain provided, use free nip.io tied to the EC2 public IP
  base_domain = var.domain_name != "" ? var.domain_name : "${var.ec2_public_ip}.nip.io"

  # TLS only when explicitly enabled and acme_email is set (cert-manager.tf)
  tls_enabled = var.enable_tls && var.acme_email != ""

  # App hostnames (pair with ingress / Traefik; HTTPS when tls_enabled)
  coder_hostname    = "coder.${local.base_domain}"
  n8n_hostname      = "n8n.${local.base_domain}"
  superset_hostname = "superset.${local.base_domain}"
  grafana_hostname  = "grafana.${local.base_domain}"

  # Coder URLs (nip.io wildcard is *.ip.nip.io, not *.coder.ip.nip.io)
  coder_access_url = local.tls_enabled ? "https://${local.coder_hostname}" : "http://${local.coder_hostname}"
  # Wildcard must be hostname pattern only — no scheme (Coder rejects "http://*....").
  # Add :port if the edge is not :80 (e.g. "*.ip.nip.io:32480" for NodePort).
  coder_wildcard_access_url = "*.${local.base_domain}"

  common_labels = {
    managed_by = "terraform"
    project    = "devops-learning"
  }
}
