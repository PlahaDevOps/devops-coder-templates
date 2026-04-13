terraform {
  required_providers {
    coder = {
      source  = "coder/coder"
      version = "~> 2.15.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 3.0.1"
    }
  }
}
provider "coder" {}
provider "kubernetes" {}
# Updated via CI
