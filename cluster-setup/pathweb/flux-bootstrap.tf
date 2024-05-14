
provider "flux" {
  kubernetes = {
    config_path = "../../talos-pathweb/kubeconfig"
  }
  git = {
    url  = "ssh://git@github.com/ruifung/rfhome-infrastructure.git"
    branch = "master"
    ssh = {
      username    = "git"
      private_key = tls_private_key.rfhome_infra_deploy_key.private_key_pem
    }
  }
}

resource "tls_private_key" "rfhome_infra_deploy_key" {
  algorithm = "ED25519"
}

# Add a deploy key
resource "github_repository_deploy_key" "rfhome_infra_deploy_key" {
  title      = "Pathweb Flux Deploy Key"
  repository = "rfhome-infrastructure"
  key        = tls_private_key.rfhome_infra_deploy_key.public_key_openssh
  read_only  = "false"
}

resource "flux_bootstrap_git" "flux_pathweb" {
  depends_on = [github_repository_deploy_key.rfhome_infra_deploy_key]

  path = "clusters/pathweb"
  namespace = "flux-system"
  embedded_manifests = true
  kustomization_override = file("${path.module}/flux-kustomization.yaml")
}