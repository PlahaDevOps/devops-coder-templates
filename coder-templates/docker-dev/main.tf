terraform {
  required_providers {
    coder = {
      source  = "coder/coder"
      version = "~> 2.15.0"
    }
    docker = {
      source  = "kreuzwerker/docker"
      version = "~> 4.0.0"
    }
  }
}

provider "coder" {}
provider "docker" {
  host = "tcp://host.docker.internal:2375"
}

data "coder_provisioner" "me" {}
data "coder_workspace" "me" {}
data "coder_workspace_owner" "me" {}

# Same base URL as the Coder server's CODER_ACCESS_URL (no hardcoded ngrok). For Docker workspaces on
# the same host, loopback hostnames must become host.docker.internal so the agent reaches the server.
locals {
  coder_access_url_for_agent = replace(
    replace(data.coder_workspace.me.access_url, "127.0.0.1", "host.docker.internal"),
    "localhost",
    "host.docker.internal"
  )
}

# Must match CODER_EXTERNAL_AUTH_0_ID on the server ("github"). Exposes access_token for other Terraform
# (e.g. Cursor MCP). For normal git clone/push over HTTPS, Coder configures GIT_ASKPASS automatically after
# you connect GitHub — do not write tokens into ~/.git-credentials in startup_script (see External Auth docs).
data "coder_external_auth" "github" {
  id = "github"
}

resource "coder_agent" "main" {
  arch = data.coder_provisioner.me.arch
  os   = "linux"

  # Without this block, the dashboard may omit VS Code / web terminal / SSH helper buttons.
  display_apps {
    vscode                 = true
    vscode_insiders        = false
    web_terminal           = true
    ssh_helper             = true
    port_forwarding_helper = true
  }

  startup_script = <<-EOT
    set -e
    echo "Welcome to your workspace!"
    sudo apt-get update -q
    sudo apt-get install -y git curl wget
    echo "Ready!"
  EOT
}

# Adds a "Cursor Desktop" button next to VS Code on the workspace page (same Coder Remote flow, opens cursor://…).
module "cursor" {
  count    = data.coder_workspace.me.start_count
  source   = "registry.coder.com/coder/cursor/coder"
  version  = "1.4.1"
  agent_id = coder_agent.main.id
  folder   = "/home/coder"
}

resource "docker_container" "workspace" {
  count = data.coder_workspace.me.start_count
  # Image includes curl/sh; init_script bootstraps the coder binary and runs the agent.
  image = "codercom/example-base:ubuntu"
  name  = "coder-${data.coder_workspace_owner.me.name}-${lower(data.coder_workspace.me.name)}"
  # So prompts look like: coder@<workspace>:~$
  hostname = data.coder_workspace.me.name

  # Provider-generated script installs/runs the agent. Loopback must become host.docker.internal or the
  # agent talks to itself (workspace container), not the Coder server on the Docker host.
  # replace() is literal substring only (the old "/localhost|127.../" pattern never matched).
  entrypoint = ["sh", "-c", replace(replace(coder_agent.main.init_script, "127.0.0.1", "host.docker.internal"), "localhost", "host.docker.internal")]

  env = [
    "CODER_AGENT_TOKEN=${coder_agent.main.token}",
    # Ensures bootstrap sees the same URL the server uses after you change CODER_ACCESS_URL (e.g. localhost → ngrok).
    # Rewritten for Docker networking; public https URLs pass through unchanged.
    "CODER_AGENT_URL=${local.coder_access_url_for_agent}",
  ]

  host {
    host = "host.docker.internal"
    ip   = "host-gateway"
  }

  volumes {
    container_path = "/home/coder"
    volume_name    = docker_volume.home.name
    read_only      = false
  }
}

resource "docker_volume" "home" {
  name = "coder-${data.coder_workspace_owner.me.name}-${data.coder_workspace.me.name}-home"
}

# PR: exercise self-hosted PR Checks workflow
