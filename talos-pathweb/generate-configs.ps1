Push-Location base
$KUBE_VERSION="1.28.3"
$TALOS_VERSION="v1.5.5"
$TALOS_FACTORY_SCHEMATIC_ID="73aca3ec1ea78b5455244413f6f01e0eb3e17a18501dddf0a6ef8074ce5bcd04"
# $TALOS_INSTALL_IMAGE="factory.talos.dev/installer/${TALOS_FACTORY_SCHEMATIC_ID}:${TALOS_VERSION}"
$TALOS_INSTALL_IMAGE="harbor.services.home.yrf.me/talos-image-factory/installer/${TALOS_FACTORY_SCHEMATIC_ID}:${TALOS_VERSION}"
talosctl gen config pathweb "https://controlplane.pathweb.clusters.home.yrf.me:6443" --output-dir _out --with-secrets secrets.yaml --with-docs=false --with-examples=false --with-kubespan --kubernetes-version $KUBE_VERSION --talos-version $TALOS_VERSION --install-image $TALOS_INSTALL_IMAGE
talosctl --talosconfig .\_out\talosconfig config endpoint controlplane.pathweb.clusters.home.yrf.me
talosctl --talosconfig .\_out\talosconfig config node pathweb-control-1.servers.home.yrf.me pathweb-control-2.servers.home.yrf.me pathweb-control-3.servers.home.yrf.me pathweb-worker-1.servers.home.yrf.me pathweb-worker-2.servers.home.yrf.me pathweb-worker-3.servers.home.yrf.me
Move-Item .\_out\controlplane.yaml .\controlplane.yaml -Force
Move-Item .\_out\worker.yaml .\worker.yaml -Force
Move-Item .\_out\talosconfig ..\talosconfig -Force
Remove-Item _out
Pop-Location