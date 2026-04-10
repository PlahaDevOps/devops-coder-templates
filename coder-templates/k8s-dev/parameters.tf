data "coder_parameter" "workspace_profile" {
  type         = "string"
  name         = "workspace_profile"
  display_name = "Workspace Profile"
  description  = "The profile of the workspace, which determines resource allocation."
  default      = "standard"
  icon         = "/emojis/1faa1.png"
  order        = 1
  mutable      = true
  form_type    = "dropdown"

  option {
    name  = "Standard (1 CPU, 1Gi RAM, 5Gi disk)"
    value = "standard"
    icon  = "/emojis/1f528.png"
  }
  option {
    name  = "Large (2 CPU, 2Gi RAM, 10Gi disk)"
    value = "large"
    icon  = "/emojis/1f4aa.png"
  }
  option {
    name  = "XLarge (4 CPU, 4Gi RAM, 20Gi disk)"
    value = "xlarge"
    icon  = "/emojis/1f680.png"
  }
}

data "coder_parameter" "repo_url" {
  type         = "string"
  name         = "repo_url"
  display_name = "Repository URL"
  description  = "URL of the repository to clone into your workspace."
  default      = "https://github.com/PlahaDevOps/devops-coder-templates"
  icon         = "/emojis/1f4d6.png"
  order        = 2
  mutable      = false

  validation {
    regex = "^$|^(https?://|ssh://|git@|git://)[a-zA-Z0-9._/:@~-]+$"
    error = "Must be a valid repository URL (https, git@, or git://)."
  }
}

data "coder_parameter" "dotfiles_uri" {
  type         = "string"
  name         = "dotfiles_uri"
  display_name = "Dotfiles URL"
  description  = "Enter a URL for a [dotfiles repository](https://dotfiles.github.io) to personalize your workspace. Use an SSH URL (e.g. `git@github.com:user/repo`) if your Git provider restricts HTTPS cloning."
  default      = ""
  icon         = "/icon/dotfiles.svg"
  order        = 3
  mutable      = true

  validation {
    regex = "^$|^(https?://|ssh://|git@|git://)[a-zA-Z0-9._/:@~-]+$"
    error = "Must be a valid dotfiles repository URL."
  }
}

data "coder_parameter" "dotfiles_branch" {
  type         = "string"
  name         = "dotfiles_branch"
  display_name = "Dotfiles Branch"
  description  = "Branch of the dotfiles repository to use."
  default      = "main"
  icon         = "/icon/dotfiles.svg"
  order        = 4
  mutable      = true
}

data "coder_parameter" "jetbrains_ide" {
  type         = "string"
  name         = "jetbrains_ide"
  display_name = "JetBrains IDEs"
  description  = "Select which JetBrains IDEs to configure for use in this workspace."
  default      = "none"
  icon         = "/icon/jetbrains.svg"
  order        = 5
  mutable      = true
  form_type    = "dropdown"

  option {
    name  = "None"
    value = "none"
  }
  option {
    name  = "IntelliJ IDEA"
    value = "intellij"
    icon  = "/icon/intellij.svg"
  }
  option {
    name  = "PyCharm"
    value = "pycharm"
    icon  = "/icon/pycharm.svg"
  }
  option {
    name  = "GoLand"
    value = "goland"
    icon  = "/icon/goland.svg"
  }
  option {
    name  = "WebStorm"
    value = "webstorm"
    icon  = "/icon/webstorm.svg"
  }
}
