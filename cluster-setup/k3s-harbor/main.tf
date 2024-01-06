terraform {
  backend "kubernetes" {
    namespace      = "kube-system"
    secret_suffix  = "state"
    config_path    = "./ruifung-k3s-harbor.yaml"
    config_context = "portainer-ctx-k3s-harbor"
  }
}

variable "kubeconfig_file" {
  type    = string
  default = "./ruifung-k3s-harbor.yaml"
}
variable "kubeconfig_ctx" {
  type    = string
  default = "portainer-ctx-k3s-harbor"
}

provider "kubernetes" {
  config_path    = var.kubeconfig_file
  config_context = var.kubeconfig_ctx
}

provider "helm" {
  debug = true
  kubernetes {
    config_path    = var.kubeconfig_file
    config_context = var.kubeconfig_ctx
  }
}

provider "kubectl" {
  config_path      = var.kubeconfig_file
  config_context   = var.kubeconfig_ctx
  load_config_file = true
}

provider "github" {
  owner = "ruifung"
}
