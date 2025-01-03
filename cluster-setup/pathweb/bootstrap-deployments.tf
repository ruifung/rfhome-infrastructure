# Bootstrap deployment of sealed-secrets, will be taken over by
# flux later.
resource "helm_release" "sealed_secrets" {
  name       = "sealed-secrets"
  repository = "https://bitnami-labs.github.io/sealed-secrets"
  chart      = "sealed-secrets"
  namespace  = "kube-system"

  lifecycle {
    # This will be managed by flux later.
    ignore_changes = all
  }
}

data "kubectl_file_documents" "multus" {
  content = file("${path.module}/multus-cni.yaml")
}

data "kubectl_file_documents" "multus-dhcp" {
  content = file("${path.module}/multus-cni-dhcp.yaml")
}


resource "kubectl_manifest" "multus" {
  for_each  = data.kubectl_file_documents.multus.manifests
  yaml_body = each.value
}

# resource "kubectl_manifest" "multus-dhcp" {
#   for_each  = data.kubectl_file_documents.multus-dhcp.manifests
#   yaml_body = each.value
# }


# Bootstrap deployment of tf-controller, will be taken over by
# flux later.
# resource "helm_release" "tf_controller" {
#   depends_on = [ flux_bootstrap_git.flux_pathweb ]

#   name       = "tf-controller"
#   repository = "https://weaveworks.github.io/tf-controller/"
#   chart      = "tf-controller"
#   namespace  = "flux-system"

#   values = [yamlencode({
#     replicaCount = 0
#   })]

#   lifecycle {
#     # This will be managed by flux later.
#     ignore_changes = all
#   }
# }
