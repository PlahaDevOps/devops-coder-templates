# DevOps Coder Templates

[Coder](https://coder.com) **workspace templates** in Terraform, with two ways to run the **Coder server** and push templates from GitHub Actions.

## Documentation

| Guide | What it covers |
|-------|----------------|
| **[docs/README-local.md](docs/README-local.md)** | **Local development** — Docker Compose, `.env`, GitHub OAuth on `localhost`, ngrok, self-hosted runner deploy secrets, troubleshooting. |
| **[docs/README-aws.md](docs/README-aws.md)** | **AWS EC2 + Ubuntu** — k3s, Helm, `coder-values.yaml`, NodePort, namespaces, GitHub secrets (`AWS_CODER_*`), ops commands, issues we hit. |

The older filename **`setup-guide.md`** still exists as a **shortcut** to the AWS doc (same content lives under `docs/`).

## Project layout (short)

```text
├── docs/
│   ├── README-local.md       ← Local Docker Compose workflow
│   └── README-aws.md         ← EC2 / k3s / Helm workflow
├── coder-templates/
│   ├── docker-dev/           ← Docker-based workspace template
│   └── k8s-dev/             ← Kubernetes workspace template
├── docker-compose.yml        ← Local Coder + ngrok
├── coder-values.yaml         ← Example Helm values (AWS); adjust for your cluster
└── .github/workflows/        ← PR checks, template deploy (local + AWS runners)
```

## Quick links

- Templates and Terraform conventions: root **[AGENTS.md](AGENTS.md)**
- Template-specific notes: **[coder-templates/docker-dev/README.md](coder-templates/docker-dev/README.md)**
