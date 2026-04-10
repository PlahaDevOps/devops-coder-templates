resource "coder_agent" "main" {
  arch = data.coder_provisioner.me.arch
  os   = "linux"
  dir  = "/home/coder"

  # Git identity injected as env vars â€” same as Aven's pattern
  env = {
    GIT_AUTHOR_NAME     = local.git_author_name
    GIT_AUTHOR_EMAIL    = local.git_author_email
    GIT_COMMITTER_NAME  = local.git_author_name
    GIT_COMMITTER_EMAIL = local.git_author_email
  }

  display_apps {
    vscode                 = true
    web_terminal           = true
    ssh_helper             = true
    port_forwarding_helper = true
    vscode_insiders        = false
  }

  startup_script_behavior = "blocking"

  startup_script = <<-EOT
    set -e
    echo "ðŸš€ Starting workspace setup..."

    # Install base tools
    sudo apt-get update -q
    sudo apt-get install -y git curl wget vim unzip jq nano

    # Setup SSH public key from Coder workspace owner
    mkdir -p ~/.ssh
    chmod 700 ~/.ssh
    echo "${data.coder_workspace_owner.me.ssh_public_key}" > ~/.ssh/id_ed25519.pub
    chmod 644 ~/.ssh/id_ed25519.pub

    # Profile-specific startup addon
    ${local.chosen_profile.startup_script_addon}

    echo "âœ… Workspace ready!"
  EOT

  # â”€â”€ Agent Metadata (dashboard stats) â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  metadata {
    display_name = "CPU Usage"
    key          = "0_cpu_usage"
    script       = "coder stat cpu"
    interval     = 10
    timeout      = 1
  }

  metadata {
    display_name = "RAM Usage"
    key          = "1_ram_usage"
    script       = "coder stat mem"
    interval     = 10
    timeout      = 1
  }

  metadata {
    display_name = "Workspace Disk"
    key          = "3_workspace_disk"
    script       = "coder stat disk --path /home/coder"
    interval     = 60
    timeout      = 1
  }

  metadata {
    display_name = "CPU Usage (Host)"
    key          = "4_cpu_usage_host"
    script       = "coder stat cpu --host"
    interval     = 10
    timeout      = 1
  }

  metadata {
    display_name = "Memory Usage (Host)"
    key          = "5_mem_usage_host"
    script       = "coder stat mem --host"
    interval     = 10
    timeout      = 1
  }

  metadata {
    display_name = "Load Average (Host)"
    key          = "6_load_host"
    script       = <<-EOT
      echo "`cat /proc/loadavg | awk '{ print $1 }'` `nproc`" | awk '{ printf "%0.2f", $1/$2 }'
    EOT
    interval     = 60
    timeout      = 1
  }

  metadata {
    display_name = "Swap Usage (Host)"
    key          = "7_swap_host"
    script       = <<-EOT
      free -b | awk '/^Swap/ { printf("%.1f/%.1f", $3/1024.0/1024.0/1024.0, $2/1024.0/1024.0/1024.0) }'
    EOT
    interval     = 10
    timeout      = 1
  }
}

# â”€â”€ Dotfiles Script â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

resource "coder_script" "dotfiles" {
  agent_id     = coder_agent.main.id
  display_name = "Dotfiles"
  icon         = "/icon/dotfiles.svg"
  run_on_start = true

  script = <<-EOT
    set -e
    DOTFILES_URL="${data.coder_parameter.dotfiles_uri.value}"
    DOTFILES_BRANCH="${data.coder_parameter.dotfiles_branch.value}"

    if [ -z "$DOTFILES_URL" ]; then
      echo "[dotfiles] No dotfiles URL provided, skipping."
      exit 0
    fi

    echo "[dotfiles] Cloning from $DOTFILES_URL (branch: $DOTFILES_BRANCH)"

    if git ls-remote --heads "$DOTFILES_URL" "$DOTFILES_BRANCH" | grep -q "$DOTFILES_BRANCH"; then
      echo "[dotfiles] Branch '$DOTFILES_BRANCH' exists."
    else
      echo "[dotfiles] Branch not found, creating from main..."
      git clone "$DOTFILES_URL" /tmp/dotfiles-temp
      cd /tmp/dotfiles-temp
      git checkout -b "$DOTFILES_BRANCH"
      git push -u origin "$DOTFILES_BRANCH" || true
      rm -rf /tmp/dotfiles-temp
    fi

    coder dotfiles "$DOTFILES_URL" --branch "$DOTFILES_BRANCH" -y 2>&1 | tee ~/.dotfiles.log
    echo "[dotfiles] Setup complete!"
  EOT
}

# â”€â”€ Workspace Metadata (shown in Coder dashboard) â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

resource "coder_metadata" "workspace_info" {
  count       = data.coder_workspace.me.start_count
  resource_id = coder_agent.main.id

  item {
    key   = "profile"
    value = local.chosen_profile.name
  }
  item {
    key   = "storage"
    value = local.chosen_profile.storage
  }
  item {
    key   = "git url"
    value = data.coder_parameter.repo_url.value == "" ? "none" : data.coder_parameter.repo_url.value
  }
  item {
    key   = "dotfiles"
    value = data.coder_parameter.dotfiles_uri.value == "" ? "none" : data.coder_parameter.dotfiles_uri.value
  }
}
