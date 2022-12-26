resource "helm_release" "metallb" {
  name             = "metallb"
  repository       = "https://metallb.github.io/metallb"
  chart            = "metallb"
  namespace        = "kube-system"
  values = [yamlencode({
    controller = {
      nodeSelector = {
        "node-role.kubernetes.io/control-plane" = ""
      }
      tolerations = [
        {
          key = "node-role.kubernetes.io/control-plane"
          operator = "Exists"
          effect = "NoSchedule"
        }
      ]
    }
  })]
}

resource "kubectl_manifest" "metallb_service_net" {
  depends_on = [
    helm_release.metallb
  ]
  yaml_body = yamlencode({
    apiVersion = "metallb.io/v1beta1",
    kind       = "IPAddressPool"
    metadata = {
      name      = "service-addr-pool"
      namespace = "kube-system"
    }
    spec = {
      addresses = [
        "10.229.30.0/24"
      ]
    }
  })
}

resource "kubectl_manifest" "metallb_service_net_l2" {
  depends_on = [
    helm_release.metallb
  ]
  yaml_body = yamlencode({
    apiVersion = "metallb.io/v1beta1",
    kind       = "L2Advertisement"
    metadata = {
      name      = "service-addr-l2"
      namespace = "kube-system"
    }
    spec = {
      ipAddressPools = [
        "service-addr-pool"
      ]
    }
  })
}