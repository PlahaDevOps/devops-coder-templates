# AGENTS.md

## Project Overview
Coder workspace templates using Terraform, deployed on k3s/Kubernetes on AWS EC2.

## Build & Validate
- Run `terraform fmt -check` to verify formatting
- Run `terraform validate` in each template directory

## Conventions
- Use snake_case for all Terraform resource and variable names
- Include descriptions for all variables
- Keep provider versions pinned
- Each template lives in its own directory

## Review Guidelines
- Verify no hardcoded secrets or API keys
- Check that all variables have sensible defaults
- Ensure resource naming follows project conventions
