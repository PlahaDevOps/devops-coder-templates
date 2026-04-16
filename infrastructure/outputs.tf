output "coder_url" {
  description = "Coder UI URL"
  value       = local.coder_access_url
}

output "coder_wildcard_access_url" {
  description = "CODER_WILDCARD_ACCESS_URL (hostname pattern for workspace apps; no scheme)"
  value       = local.coder_wildcard_access_url
}

output "n8n_url" {
  description = "n8n URL when enabled"
  value       = var.n8n_enabled ? "http://${local.n8n_hostname}" : "not deployed"
}

output "grafana_url" {
  description = "Grafana access URL when enabled"
  value       = var.grafana_enabled ? "http://${local.grafana_hostname}" : "not deployed"
}

output "base_domain" {
  description = "Base domain for services (nip.io or custom)"
  value       = local.base_domain
}

output "tls_enabled" {
  description = "Whether HTTPS is configured (enable_tls and acme_email → cert-manager + Let's Encrypt)"
  value       = local.tls_enabled
}
