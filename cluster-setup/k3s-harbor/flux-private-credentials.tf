# Fetch github metadata
data "http" "github_meta" {
  url = "https://api.github.com/meta"
}

locals {
  gh_ssh_keys    = jsondecode(data.http.github_meta.response_body).ssh_keys
  gh_known_hosts = formatlist("github.com %s", local.gh_ssh_keys)
}

resource "tls_private_key" "rfhome_infra_private_deploy_key" {
  algorithm = "ED25519"
}

resource "github_repository_deploy_key" "rfhome_infra_private_deploy_key" {
  title      = "Pi4-01 Flux Deploy Key"
  repository = "rfhome-infrastructure-private"
  key        = tls_private_key.rfhome_infra_private_deploy_key.public_key_openssh
  read_only  = "true"
}

resource "kubernetes_secret_v1" "rfhome_private" {
  metadata {
    name      = "rfhome-private"
    namespace = flux_bootstrap_git.flux.namespace
  }

  data = {
    identity    = tls_private_key.rfhome_infra_private_deploy_key.private_key_openssh
    known_hosts = join("\n", local.gh_known_hosts)
  }
}