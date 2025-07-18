terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.95, < 6.0.0"
    }
  }
  required_version = ">= 1.3.7"
}

provider "helm" {
  kubernetes = {
    config_path = "~/.kube/config"
  }
}
