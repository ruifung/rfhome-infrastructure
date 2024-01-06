Push-Location base
$KUBE_VERSION="1.29.0"
$TALOS_VERSION="v1.6.1"
$TALOS_FACTORY_SCHEMATIC_ID="20f0f58646bf4fbb1f4f4256484fbf4955dde1f0baf46306834b6ebdda71128d"
# $TALOS_INSTALL_IMAGE="factory.talos.dev/installer/${TALOS_FACTORY_SCHEMATIC_ID}:${TALOS_VERSION}"
$TALOS_INSTALL_IMAGE="factory.talos.dev/installer/${TALOS_FACTORY_SCHEMATIC_ID}:${TALOS_VERSION}"
talosctl gen config talos-harbor "https://talos-harbor.servers.home.yrf.me:6443" --output-dir _out --with-secrets secrets.yaml --with-docs=false --with-examples=false --kubernetes-version $KUBE_VERSION --talos-version $TALOS_VERSION --install-image $TALOS_INSTALL_IMAGE
talosctl --talosconfig .\_out\talosconfig config endpoint talos-harbor.servers.home.yrf.me
talosctl --talosconfig .\_out\talosconfig config node talos-harbor.servers.home.yrf.me
Move-Item .\_out\controlplane.yaml .\controlplane.yaml -Force
Move-Item .\_out\worker.yaml .\worker.yaml -Force
Move-Item .\_out\talosconfig ..\talosconfig -Force
Remove-Item _out
Pop-Location