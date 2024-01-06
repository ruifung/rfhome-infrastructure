terraform {
  backend "kubernetes" {
    namespace      = "kube-system"
    secret_suffix  = "state"
    config_path    = "../../talos-harbor/kubeconfig"
    config_context = "admin@talos-harbor"
  }
}

variable "kubeconfig_file" {
  type    = string
  default = "../../talos-harbor/kubeconfig"
}
variable "kubeconfig_ctx" {
  type    = string
  default = "admin@talos-harbor"
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
