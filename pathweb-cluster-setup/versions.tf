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

    flux = {
      source  = "fluxcd/flux"
      version = "0.22.2"
    }


    github = {
      source  = "integrations/github"
      version = "~> 5.0"
    }

    tls = {
      source  = "hashicorp/tls"
      version = "4.0.4"
    }

    http = {
      source  = "hashicorp/http"
      version = "3.2.1"
    }
  }

  backend "kubernetes" {
    namespace      = "kube-system"
    secret_suffix  = "state"
    config_path    = "../talos-pathweb/kubeconfig"
    config_context = "admin@pathweb"
  }
}
