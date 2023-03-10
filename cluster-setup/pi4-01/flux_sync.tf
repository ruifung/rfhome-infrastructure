# Generate manifests
data "flux_sync" "main" {
  target_path = "clusters/pi4-01"
  url         = "ssh://git@github.com/ruifung/rfhome-infrastructure.git"
  branch      = "master"
}

# Split multi-doc YAML with
# https://registry.terraform.io/providers/gavinbunney/kubectl/latest
data "kubectl_file_documents" "sync" {
  content = data.flux_sync.main.content
}

# Convert documents list to include parsed yaml data
locals {
  sync = [for v in data.kubectl_file_documents.sync.documents : {
    data : yamldecode(v)
    content : v
    }
  ]
}

# Apply manifests on the cluster
resource "kubectl_manifest" "sync" {
  for_each   = { for v in local.sync : lower(join("/", compact([v.data.apiVersion, v.data.kind, lookup(v.data.metadata, "namespace", ""), v.data.metadata.name]))) => v.content }
  depends_on = [kubernetes_namespace_v1.flux_system]
  yaml_body  = each.value

  lifecycle {
    # This will be managed by flux later.
    ignore_changes = all
  }
}

# Generate Deploy Key
resource "tls_private_key" "rfhome_infra_deploy_key" {
  algorithm = "ED25519"
}

# Add a deploy key
resource "github_repository_deploy_key" "rfhome_infra_deploy_key" {
  title      = "Pi4-01 Flux Deploy Key"
  repository = "rfhome-infrastructure"
  key        = tls_private_key.rfhome_infra_deploy_key.public_key_openssh
  read_only  = "true"
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


# Fetch github metadata
data "http" "github_meta" {
  url = "https://api.github.com/meta"
}

locals {
  gh_ssh_keys    = jsondecode(data.http.github_meta.response_body).ssh_keys
  gh_known_hosts = formatlist("github.com %s", local.gh_ssh_keys)
}

# Generate a Kubernetes secret with the Git credentials
resource "kubernetes_secret_v1" "main" {
  depends_on = [kubectl_manifest.apply]

  metadata {
    name      = data.flux_sync.main.secret
    namespace = data.flux_sync.main.namespace
  }

  data = {
    identity    = tls_private_key.rfhome_infra_deploy_key.private_key_openssh
    known_hosts = join("\n", local.gh_known_hosts)
  }
}

resource "kubernetes_secret_v1" "rfhome_private" {
  depends_on = [kubectl_manifest.apply]

  metadata {
    name      = "rfhome-private"
    namespace = data.flux_sync.main.namespace
  }

  data = {
    identity    = tls_private_key.rfhome_infra_private_deploy_key.private_key_openssh
    known_hosts = join("\n", local.gh_known_hosts)
  }
}

resource "github_repository_file" "sync" {
  repository = "rfhome-infrastructure"
  file       = data.flux_sync.main.path
  content    = data.flux_sync.main.content
  branch     = "master"
}

resource "github_repository_file" "kustomize" {
  repository = "rfhome-infrastructure"
  file       = data.flux_sync.main.kustomize_path
  content    = data.flux_sync.main.kustomize_content
  branch     = "master"
}