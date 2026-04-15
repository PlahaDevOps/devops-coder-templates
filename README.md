# DevOps Coder Templates

[Coder](https://coder.com) **workspace templates** in Terraform, with two ways to run the **Coder server** and push templates from GitHub Actions.

## Documentation

| Guide | What it covers |
|-------|----------------|
| **[docs/README-local.md](docs/README-local.md)** | **Local development** — Docker Compose, `.env`, GitHub OAuth on `localhost`, ngrok, self-hosted runner deploy secrets, troubleshooting. |
| **[docs/README-aws.md](docs/README-aws.md)** | **AWS EC2 + Ubuntu** — k3s, Terraform (`infrastructure/`) for Coder Helm + ingress, GitHub secrets (`AWS_CODER_*`), ops commands, issues we hit. |

## Project layout (short)

```text
├── docs/
│   ├── README-local.md       ← Local Docker Compose workflow
│   └── README-aws.md         ← EC2 / k3s / Coder server + templates
├── infrastructure/           ← Terraform: Coder Helm release, ingress, namespaces (AWS)
├── coder-templates/
│   ├── docker-dev/           ← Docker-based workspace template
│   └── k8s-dev/             ← Kubernetes workspace template
├── docker-compose.yml        ← Local Coder + ngrok
└── .github/workflows/        ← PR checks, template deploy (local + AWS runners)
```

## Quick links

- Templates and Terraform conventions: root **[AGENTS.md](AGENTS.md)**
- Template-specific notes: **[coder-templates/docker-dev/README.md](coder-templates/docker-dev/README.md)**
