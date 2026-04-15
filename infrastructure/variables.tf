# ─── Cluster ────────────────────────────────────────
variable "kubeconfig_path" {
  description = "Path to k3s kubeconfig (on the EC2 host: /etc/rancher/k3s/k3s.yaml; copy to ~/.kube/config if running as non-root)"
  type        = string
  default     = "/etc/rancher/k3s/k3s.yaml"
}

# ─── Networking ─────────────────────────────────────
variable "ec2_public_ip" {
  description = "EC2 instance public IP"
  type        = string
}

variable "domain_name" {
  description = "Base domain (leave empty to use <ip>.nip.io)"
  type        = string
  default     = ""
}

# ─── TLS (Let's Encrypt via cert-manager) ─────────────
variable "enable_tls" {
  description = "If true, deploy cert-manager and serve Coder over HTTPS (requires acme_email). If false, HTTP only and no cert-manager resources."
  type        = bool
  default     = false
}

variable "acme_email" {
  description = "Email for Let's Encrypt (required when enable_tls is true). Ignored when enable_tls is false."
  type        = string
  default     = ""
}

variable "acme_use_staging" {
  description = "Use Let's Encrypt staging (avoids rate limits while testing; browsers will not trust the cert)"
  type        = bool
  default     = false
}

variable "cert_manager_version" {
  description = "cert-manager Helm chart version (Jetstack)"
  type        = string
  default     = "v1.14.5"
}

# ─── Coder ──────────────────────────────────────────
variable "coder_version" {
  description = "Coder Helm chart version"
  type        = string
  default     = "2.31.5"
}

variable "github_oauth_client_id" {
  description = "GitHub OAuth App Client ID for Coder login"
  type        = string
  sensitive   = true
}

variable "github_oauth_client_secret" {
  description = "GitHub OAuth App Client Secret for Coder login"
  type        = string
  sensitive   = true
}

variable "anthropic_api_key" {
  description = "Anthropic API key for Claude Code in workspaces"
  type        = string
  sensitive   = true
  default     = "placeholder"
}

# ─── n8n (future) ───────────────────────────────────
variable "n8n_enabled" {
  description = "Whether to deploy n8n"
  type        = bool
  default     = false
}
