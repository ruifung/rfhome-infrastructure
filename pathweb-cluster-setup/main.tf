provider "kubernetes" {
  config_path    = "../talos-pathweb/kubeconfig"
  config_context = "admin@pathweb"
}

provider "helm" {
  debug = true
  kubernetes {
    config_path    = "../talos-pathweb/kubeconfig"
    config_context = "admin@pathweb"
  }
}

provider "kubectl" {
  config_path    = "../talos-pathweb/kubeconfig"
  config_context = "admin@pathweb"
  load_config_file = true
}
