terraform {
  backend "kubernetes" {
    namespace      = "kube-system"
    secret_suffix  = "state"
    config_path    = "./ruifung-server-pi-01-k3s.yaml"
    config_context = "portainer-ctx-server-pi-01-k3s"
  }
}

variable "kubeconfig_file" {
  type    = string
  default = "./ruifung-server-pi-01-k3s.yaml"
}
variable "kubeconfig_ctx" {
  type    = string
  default = "portainer-ctx-server-pi-01-k3s"
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
