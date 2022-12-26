terraform {
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.0.3"
    }

    helm = {
      source  = "hashicorp/helm"
      version = ">= 2.1.0"
    }

    kubectl = {
      source  = "gavinbunney/kubectl"
      version = "1.14.0"
    }
  }
}