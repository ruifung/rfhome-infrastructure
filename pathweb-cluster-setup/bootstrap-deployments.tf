resource "helm_release" "sealed_secrets" {
  name       = "sealed-secrets"
  repository = "https://bitnami-labs.github.io/sealed-secrets"
  chart      = "sealed-secrets"
  namespace  = "kube-system"
}

data "kubectl_file_documents" "multus" {
  content = file("${path.module}/multus-cni.yaml")
}

resource "kubectl_manifest" "multus" {
  for_each  = data.kubectl_file_documents.multus.manifests
  yaml_body = each.value
}

resource "helm_release" "tf_controller" {
  name       = "tf-controller"
  repository = "https://weaveworks.github.io/tf-controller/"
  chart      = "tf-controller"
  namespace  = "flux-system"

  values = [yamlencode({
    replicaCount = 0
  })]
}
