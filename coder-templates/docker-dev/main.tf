terraform {
  required_providers {
    coder = {
      source = "coder/coder"
    }
    docker = {
      source = "kreuzwerker/docker"
    }
  }
}

provider "coder" {}
provider "docker" {
  host = "unix:///var/run/docker.sock"
}

data "coder_provisioner" "me" {}
data "coder_workspace" "me" {}
data "coder_workspace_owner" "me" {}

# Matches CODER_EXTERNAL_AUTH_0_ID in Coder server docker-compose.yml (Git HTTPS + repos).
data "coder_external_auth" "github" {
  id = "github"
}

resource "coder_agent" "main" {
  arch = data.coder_provisioner.me.arch
  os   = "linux"

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

  # Provider-generated script installs/runs the agent; rewrite loopback so the agent reaches Coder on the host.
  entrypoint = ["sh", "-c", replace(coder_agent.main.init_script, "/localhost|127\\.0\\.0\\.1/", "host.docker.internal")]

  env = [
    "CODER_AGENT_TOKEN=${coder_agent.main.token}",
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
