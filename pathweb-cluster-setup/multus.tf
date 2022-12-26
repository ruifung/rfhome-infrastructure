data "kubectl_file_documents" "multus" {
  content = file("${path.module}/multus-daemonset.yaml")
}

resource "kubectl_manifest" "multus" {
  for_each  = data.kubectl_file_documents.multus.manifests
  yaml_body = each.value
}