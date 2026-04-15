locals {
  # If no domain provided, use free nip.io tied to the EC2 public IP
  base_domain = var.domain_name != "" ? var.domain_name : "${var.ec2_public_ip}.nip.io"

  # App hostnames (HTTP — pair with ingress / Traefik on :80)
  coder_hostname    = "coder.${local.base_domain}"
  n8n_hostname      = "n8n.${local.base_domain}"
  superset_hostname = "superset.${local.base_domain}"
  grafana_hostname  = "grafana.${local.base_domain}"

  # Coder URLs (nip.io wildcard is *.ip.nip.io, not *.coder.ip.nip.io)
  coder_access_url          = "http://${local.coder_hostname}"
  coder_wildcard_access_url = "http://*.${local.base_domain}"

  common_labels = {
    managed_by = "terraform"
    project    = "devops-learning"
  }
}
