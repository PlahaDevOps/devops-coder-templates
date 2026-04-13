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
| `~/coder-values.yaml` | Helm values for Coder (URL, resources, GitHub OAuth) |
| `~/devops-coder-templates/` | Cloned GitHub repo with Coder templates |

### In the GitHub Repo

| File/Path | Purpose |
|-----------|---------|
| `.github/workflows/deploy-coder-aws.yml` | CI/CD pipeline for AWS deployment |
| `.github/workflows/deploy-template.yml` | Pipeline for local/Windows self-hosted runner (`CODER_URL` / `CODER_TOKEN`) |
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

### Coder Management
```bash
# Check Coder pod
sudo kubectl get pods -n coder

# Check Coder service (find the NodePort)
sudo kubectl get svc -n coder

# View Coder logs
sudo kubectl logs -n coder -l app.kubernetes.io/name=coder --tail=50

# Helm operations
helm list -n coder                    # List releases
helm upgrade coder coder-v2/coder \   # Upgrade with new values
  --namespace coder \
  --values coder-values.yaml
helm uninstall coder -n coder         # Uninstall
```

### Coder CLI
```bash
# Login
export CODER_URL=http://18.191.148.4:32480
coder login $CODER_URL

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

### 1. Pod Evictions (Insufficient Memory)
**Problem:** Coder's default resource requests (2 CPU, 4GB RAM) exceeded t3.small capacity.
**Fix:** Lowered resource requests in `coder-values.yaml`:
```yaml
resources:
  requests:
    cpu: "250m"
    memory: "256Mi"
  limits:
    cpu: "500m"
    memory: "512Mi"
```

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
| 443 | HTTPS |
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
4. Find the new NodePort: `sudo kubectl get svc -n coder`
5. Update `coder-values.yaml` with new IP and upgrade Helm
6. Update `AWS_CODER_URL` secret in GitHub
7. Open the NodePort in Security Group if needed
