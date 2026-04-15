# Coder on AWS EC2 (k3s + Helm)

Deploy the Coder **server** on Ubuntu EC2 with k3s and **Terraform** under [`infrastructure/`](../infrastructure/) (Helm release + ingress). For **local Docker Compose** development on your laptop, see **[README-local.md](./README-local.md)**.

← [Repository overview](../README.md)

---

# Kubernetes + Coder on AWS EC2 — Complete Setup Guide

## What We Built

A cloud-based development environment where developers can spin up isolated workspaces with one click, all running on Kubernetes with automated CI/CD.

```
┌─────────────────────────────────────────────────────────┐
│  AWS EC2 (t3.small - Ubuntu 24.04)                      │
│                                                         │
│  ┌───────────────────────────────────────────────────┐  │
│  │  k3s (Lightweight Kubernetes)                     │  │
│  │                                                   │  │
│  │  ┌─────────────┐  ┌────────────────────────────┐  │  │
│  │  │ coder       │  │ coder-workspaces           │  │  │
│  │  │ namespace   │  │ namespace                  │  │  │
│  │  │             │  │                            │  │  │
│  │  │ Coder Server│  │ Dev Workspace Pods         │  │  │
│  │  │ (Helm)      │  │ (created by templates)     │  │  │
│  │  └─────────────┘  └────────────────────────────┘  │  │
│  └───────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────┘

┌──────────────┐    ┌──────────────┐    ┌───────────────┐
│ Local Dev    │───▶│ GitHub       │───▶│ Coder on AWS  │
│ (push code)  │    │ Actions CI/CD│    │ (auto-deploy) │
└──────────────┘    └──────────────┘    └───────────────┘
```

---

## Layer-by-Layer Breakdown

### Layer 1: AWS EC2
**What:** A virtual Linux server in Amazon's cloud.
**Why:** Gives us a machine to run everything on.
**Specs used:** t3.small (2 vCPU, 2GB RAM, 20GB disk, ~$0.02/hr)

### Layer 2: k3s (Kubernetes)
**What:** A lightweight Kubernetes distribution.
**Why:** Manages containers — starts, stops, restarts, networks them.
**Think of it as:** The operating system for containers.

### Layer 3: Helm
**What:** A package manager for Kubernetes.
**Why:** Instead of writing 10+ YAML files to deploy Coder, Helm does it in one command.
**Think of it as:** `apt install` but for Kubernetes apps.

### Layer 4: Coder
**What:** A platform that creates cloud development environments (workspaces).
**Why:** Developers get consistent, isolated environments via a web browser.
**Think of it as:** VS Code in the cloud, managed by Kubernetes.

### Layer 5: Templates
**What:** Terraform configs that define what a workspace looks like.
**Why:** Ensures every developer gets the same tools, repos, and setup.
**We have two:**
- `docker-dev` — workspaces using Docker containers
- `k8s-dev` — workspaces using Kubernetes pods (with Claude Code AI)

### Layer 6: GitHub Actions CI/CD
**What:** Automated pipeline that deploys templates when code is pushed.
**Why:** No manual work — push to GitHub, templates update automatically.

---

## How Everything Connects

```
Developer pushes code to GitHub
        │
        ▼
GitHub Actions workflow triggers
(deploy-coder-aws.yml)
        │
        ▼
Coder CLI installs on GitHub runner
        │
        ▼
CLI logs into Coder using API token
(secrets: AWS_CODER_URL, AWS_CODER_TOKEN)
        │
        ▼
Templates pushed to Coder server
(coder templates push docker-dev/k8s-dev)
        │
        ▼
Coder updates templates on k3s cluster
        │
        ▼
Developers create workspaces from updated templates
```

---

## Key Files & Their Purpose

### On the EC2 Server

| File/Path | Purpose |
|-----------|---------|
| `/etc/rancher/k3s/k3s.yaml` | k3s kubeconfig (how tools talk to the cluster) |
| `~/devops-coder-templates/infrastructure/` | Terraform for Coder Helm values (`coder.tf`), ingress, namespaces; `terraform.tfvars` for EC2 IP and secrets |
| `~/devops-coder-templates/` | Cloned GitHub repo with templates and infrastructure code |

### In the GitHub Repo

| File/Path | Purpose |
|-----------|---------|
| `infrastructure/` | Terraform: Coder Helm release, Traefik ingress, RBAC, secrets (OAuth, etc.) |
| `.github/workflows/deploy-coder-aws.yml` | CI/CD pipeline for AWS deployment |
| `.github/workflows/deploy-template.yml` | **Manual only** — local Coder via Windows self-hosted runner (`CODER_URL` / `CODER_TOKEN`) |
| `coder-templates/docker-dev/` | Docker-based workspace template |
| `coder-templates/k8s-dev/main.tf` | Kubernetes provider config (uses in-cluster auth) |
| `coder-templates/k8s-dev/kubernetes.tf` | Pod and PVC definitions for workspaces |

### GitHub Secrets

| Secret | Value | Used By |
|--------|-------|---------|
| `CODER_URL` | Local Coder URL | `deploy-template.yml` (Windows self-hosted runner) |
| `CODER_TOKEN` | Local Coder token | `deploy-template.yml` |
| `AWS_CODER_URL` | e.g. `http://<EC2_IP>:<NodePort>` | `deploy-coder-aws.yml` |
| `AWS_CODER_TOKEN` | Coder API token | `deploy-coder-aws.yml` |

### Kubernetes Secrets

| Secret | Namespace | Purpose |
|--------|-----------|---------|
| `coder-github-oauth` | `coder` | GitHub OAuth Client ID & Secret |
| `anthropic-api-key` | `coder-workspaces` | API key for Claude Code in workspaces |

---

## Kubernetes Namespaces

| Namespace | What Lives Here |
|-----------|-----------------|
| `kube-system` | k3s system pods (CoreDNS, Traefik, metrics-server) |
| `coder` | Coder server pod, service account, secrets |
| `coder-workspaces` | Developer workspace pods, PVCs, service accounts |

---

## Important Commands Reference

### Cluster Management
```bash
# Check nodes
sudo kubectl get nodes

# Check all pods
sudo kubectl get pods -A

# Check resource usage
sudo kubectl top nodes
free -m
df -h /
```

### HTTPS (Let's Encrypt via Terraform)

Optional TLS is in **`infrastructure/cert-manager.tf`**: set **`enable_tls = true`**, **`acme_email`**, open EC2 **TCP 443**, run **`terraform apply`**. Use **`enable_tls = false`** (default) for HTTP only. Update your **GitHub OAuth app** callback URL to **`https://`** when using TLS (see Coder’s external auth docs for the exact path).

If you previously had a failed **`kubernetes_manifest`** ClusterIssuer in Terraform state, remove it once: **`terraform state rm 'kubernetes_manifest.clusterissuer_letsencrypt[0]'`** (or the address shown in **`terraform state list`**), then apply again.

Let’s Encrypt uses **HTTP-01**, so it can issue a cert for the main hostname (e.g. `coder.x.x.x.nip.io`). A **wildcard** cert for `*.x.x.x.nip.io` needs **DNS-01** with a DNS provider; workspace preview URLs may still show “Not secure” until you use a real domain with DNS automation.

### Coder Management
```bash
# Check Coder pod
sudo kubectl get pods -n coder

# Check Coder service (find the NodePort)
sudo kubectl get svc -n coder

# View Coder logs
sudo kubectl logs -n coder -l app.kubernetes.io/name=coder --tail=50

# Terraform (preferred — Helm values are defined in infrastructure/coder.tf)
cd ~/devops-coder-templates/infrastructure && terraform apply

# Helm only (debugging; keep in sync with coder.tf)
helm list -n coder
helm upgrade coder coder --repo https://helm.coder.com/v2 --namespace coder --reuse-values
helm uninstall coder -n coder
```

### Coder CLI
```bash
# Login (use the same URL as in the browser — e.g. Traefik ingress on :80)
export CODER_URL=http://coder.<YOUR_PUBLIC_IP>.nip.io
coder login "$CODER_URL"

# List templates
coder templates list

# Push a template
coder templates push k8s-dev --directory ./coder-templates/k8s-dev --yes

# Create a workspace
coder create my-workspace --template k8s-dev

# Delete a workspace
coder delete my-workspace --yes
```

### Workspace Management
```bash
# Check workspace pods
sudo kubectl get pods -n coder-workspaces

# Describe a workspace pod (for debugging)
sudo kubectl describe pod <pod-name> -n coder-workspaces
```

---

## Problems We Hit & How We Fixed Them

### 1. Pod evictions / CrashLoopBackOff (memory or config)
**Problem:** Chart defaults can exceed a small node, or explicit `resources` in Terraform are too low (OOM), or `CODER_WILDCARD_ACCESS_URL` included a scheme (`http://`) and Coder refused to start.
**Fix:** Tune the `coder` Helm `values` block in **`infrastructure/coder.tf`** (and `locals.tf` for URLs). Wildcard access URL must be a **hostname pattern only** (e.g. `*.203.0.113.nip.io`), not `http://*.…`.

### 2. Disk Full (8GB instead of 20GB)
**Problem:** EC2 launched with default 8GB disk, not 20GB.
**Fix:** Expanded EBS volume in AWS Console, then:
```bash
sudo growpart /dev/nvme0n1 1
sudo resize2fs /dev/nvme0n1p1
```

### 3. NodePort Out of Range
**Problem:** Tried to use port 3000, but Kubernetes NodePorts must be 30000-32767.
**Fix:** Used the auto-assigned NodePort and opened it in Security Group.

### 4. Kubernetes Provider Config
**Problem:** Template had `config_path = "~/.kube/config"` (for local Docker Desktop).
**Fix:** Changed to empty provider block `provider "kubernetes" {}` for in-cluster auth.

### 5. RBAC Permissions
**Problem:** Coder service account couldn't create pods in `coder-workspaces`.
**Fix:**
```bash
sudo kubectl create namespace coder-workspaces
sudo kubectl create rolebinding coder-admin \
  --clusterrole=admin \
  --serviceaccount=coder:coder \
  --namespace=coder-workspaces
sudo kubectl create serviceaccount coder --namespace coder-workspaces
```

### 6. Missing Anthropic API Key Secret
**Problem:** Template expected `anthropic-api-key` secret.
**Fix:**
```bash
sudo kubectl create secret generic anthropic-api-key \
  --namespace coder-workspaces \
  --from-literal=api-key=placeholder
```

### 7. GitHub OAuth Not Configured
**Problem:** docker-dev template needed GitHub external auth.
**Fix:** Created GitHub OAuth App, stored credentials in Kubernetes secret, referenced in Helm values.

---

## Security Group Ports

| Port | Purpose |
|------|---------|
| 22 | SSH access |
| 80 | HTTP |
| 443 | HTTPS (required when `enable_tls = true` and `acme_email` are set in `terraform.tfvars`) |
| 6443 | Kubernetes API |
| 8080 | Apps |
| 30000-32767 | Kubernetes NodePort range (open this full range) |

---

## Cost Awareness

| Resource | Cost |
|----------|------|
| t3.small | ~$0.02/hour (~$0.48/day) |
| 20GB gp3 EBS | ~$1.60/month |
| **Total running 24/7** | **~$16/month** |

**Save money:**
- Stop the EC2 instance when not using it
- Stop workspaces when not coding
- The IP will change on restart (use Elastic IP if needed — $3.65/month when attached to a stopped instance)

---

## Quick Restart Guide

If you stop and restart the EC2 instance:

1. Note the **new public IP** from AWS Console
2. SSH in with the new IP
3. k3s and Coder should auto-start
4. Find the new NodePort (if using NodePort): `sudo kubectl get svc -n coder`
5. Set **`ec2_public_ip`** in `infrastructure/terraform.tfvars`, then run **`terraform apply`** in `infrastructure/`
6. Update `AWS_CODER_URL` secret in GitHub
7. Open the NodePort in Security Group if needed
