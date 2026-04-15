output "coder_url" {
  description = "Coder UI URL"
  value       = local.coder_access_url
}

output "coder_wildcard_access_url" {
  description = "CODER_WILDCARD_ACCESS_URL value (workspace apps)"
  value       = local.coder_wildcard_access_url
}

output "n8n_url" {
  description = "n8n URL when enabled"
  value       = var.n8n_enabled ? "http://${local.n8n_hostname}" : "not deployed"
}

output "base_domain" {
  description = "Base domain for services (nip.io or custom)"
  value       = local.base_domain
}
