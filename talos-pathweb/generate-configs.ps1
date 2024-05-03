$ErrorActionPreference = "Stop"

Push-Location base

$KUBE_VERSION="1.29.3"
$TALOS_VERSION="v1.7.0"
$TALOS_FACTORY_SCHEMATIC_ID="71fdc73baac9ae32e13435992ba56d469b4eaf3fb561125e1af41505210bdb35"
# $TALOS_INSTALL_IMAGE="factory.talos.dev/installer/${TALOS_FACTORY_SCHEMATIC_ID}:${TALOS_VERSION}"
$TALOS_INSTALL_IMAGE="factory.talos.dev/installer/${TALOS_FACTORY_SCHEMATIC_ID}:${TALOS_VERSION}"
talosctl gen config pathweb "https://controlplane.pathweb.clusters.home.yrf.me:6443" --output-dir _out --with-secrets secrets.yaml --with-docs=false --with-examples=false --with-kubespan --kubernetes-version $KUBE_VERSION --talos-version $TALOS_VERSION --install-image $TALOS_INSTALL_IMAGE
talosctl --talosconfig .\_out\talosconfig config endpoint controlplane.pathweb.clusters.home.yrf.me
talosctl --talosconfig .\_out\talosconfig config node pathweb-control-1.servers.home.yrf.me pathweb-control-2.servers.home.yrf.me pathweb-control-3.servers.home.yrf.me pathweb-worker-1.servers.home.yrf.me pathweb-worker-2.servers.home.yrf.me pathweb-worker-3.servers.home.yrf.me pathweb-worker-baldric.servers.home.yrf.me

Move-Item _out\talosconfig ..\talosconfig -Force
Move-Item _out\controlplane.yaml controlplane.yaml -Force
Move-Item _out\worker.yaml worker.yaml -Force
Remove-Item _out

Pop-Location

$nodes = Get-Content nodes.json -Raw | ConvertFrom-Json
New-Item -ItemType Directory -Force machineconfig | Out-Null
foreach ($node in $nodes) {
    $base = "NONEXISTENTFILE"
    if ($node.role -eq "controlplane") {
        $base = ".\base\controlplane.yaml"
    } elseif ($node.role -eq "worker") {
        $base = ".\base\worker.yaml"
    }
    $machineConfigFile = ".\machineconfig\$($node.fqdn).yaml"
    $patchArgs = [System.Collections.ArrayList]@($base, "-o", $machineConfigFile)

    $node.patches | ForEach-Object { "@$($_ -replace '/','\')" } | ForEach-Object {
        $patchArgs.Add("-p") | Out-Null
        $patchArgs.Add($_) | Out-Null
    }

    Write-Output "Generating MachineConfig for node $($node.fqdn) with patch set [$($node.patches)]"
    talosctl machineconfig patch @patchArgs
}
