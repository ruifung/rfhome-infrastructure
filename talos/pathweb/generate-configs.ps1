$ErrorActionPreference = "Stop"


$versions = Get-Content talos-version.json -Raw | ConvertFrom-Json
$TALOS_VERSION=$versions.version
$KUBE_VERSION=$versions.k8s_version

Push-Location base
talosctl gen config pathweb "https://controlplane.pathweb.clusters.home.yrf.me:6443" --output-dir _out --with-secrets secrets.yaml --with-docs=false --with-examples=false --with-kubespan --kubernetes-version $KUBE_VERSION --talos-version $TALOS_VERSION
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

    $VERSION = $versions.version
    if ($versions.image_override.$($node.type) -is [string]) {
        $SCHEMATIC = $null
        $IMAGE = $versions.image_override.$($node.type)
    }
    else {
        $SCHEMATIC = $versions.schematics.$($node.type)
        $IMAGE = "$($versions.factory_image_registry)/installer/${SCHEMATIC}:${VERSION}"
    }
    $ImagePatch = @{
        machine = @{
            install = @{
                image = $IMAGE
            }
        }
    }
    $ImagePatchJson = ConvertTo-Json $ImagePatch -Compress
    $patchArgs.Add("-p") | Out-Null
    $patchArgs.Add($ImagePatchJson) | Out-Null

    Write-Output "Generating MachineConfig for node $($node.fqdn) with patch set [$($node.patches)] and installer image [$IMAGE]"
    talosctl machineconfig patch @patchArgs
    Write-Output "Uploading generated MachineConfig to S3."
    mc cp -q --checksum SHA256 $machineConfigFile okinawa-vgw/rfhome-talos-config/pathweb/machineconfig/
}

Write-Output "Syncronizing generated MachineConfigs to S3."
mc mirror -q --checksum SHA256 --remove --overwrite --exclude .gitignore base okinawa-vgw/rfhome-talos-config/pathweb/base
mc mirror -q --checksum SHA256 --remove --overwrite --exclude .gitignore patches okinawa-vgw/rfhome-talos-config/pathweb/patches
mc mirror -q --checksum SHA256 --remove --overwrite --exclude .gitignore machineconfig okinawa-vgw/rfhome-talos-config/pathweb/machineconfig
