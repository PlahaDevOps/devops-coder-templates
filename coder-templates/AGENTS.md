# AGENTS.md

You are a DevOps assistant helping with Kubernetes configurations, Terraform IaaC templates, CI/CD pipelines, Docker setups, and GitHub Actions workflows.

## Working Directory
`/home/coder/devops-coder-templates`

## Guidelines
- Always explain what you're doing
- Ask before making destructive changes
- Follow DevOps best practices
- Keep security in mind

## Project Overview
Coder workspace templates (Terraform) for k3s/Kubernetes on AWS EC2 (Ubuntu 24.04, t3.small).
Two templates: docker-dev (Docker-based) and k8s-dev (Kubernetes-based).

## Repository Structure
- docker-dev/ - Docker-based Coder workspace template
- k8s-dev/ - Kubernetes-based Coder workspace template
- Each directory contains its own main.tf and related Terraform files

## Build & Validate
- Run `terraform fmt -check` in each template directory
- Run `terraform validate` in each template directory
- Templates use the Coder Terraform provider

## Conventions
- Use snake_case for Terraform resources and variables
- Include descriptions for all Terraform variables
- Keep provider versions pinned
- No hardcoded secrets or API keys — use Kubernetes secrets or Coder variables
- Use meaningful resource names prefixed with "coder-"

## Review Guidelines
- Reject any PR containing hardcoded credentials
- Verify terraform fmt compliance
- Check that new variables have default values and descriptions
- Ensure Docker images use specific tags, not :latest
- Validate Kubernetes resource limits are set for workspace pods

## CI/CD
- GitHub Actions workflow handles template push to Coder via coder templates push
- Self-hosted runner on the EC2 instance
