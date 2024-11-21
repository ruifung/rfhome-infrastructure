$ErrorActionPreference = "Stop"


$versions = Get-Content talos-version.json -Raw | ConvertFrom-Json
$TALOS_VERSION=$versions.version
$KUBE_VERSION=$versions.k8s_version

Push-Location base
talosctl gen config pathweb "https://frog.clusters.home.yrf.me:6443" --output-dir _out --with-secrets secrets.yaml --with-docs=false --with-examples=false --kubernetes-version $KUBE_VERSION --talos-version $TALOS_VERSION
talosctl --talosconfig .\_out\talosconfig config endpoint frog.clusters.home.yrf.me
talosctl --talosconfig .\_out\talosconfig config node frog.clusters.home.yrf.me

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
}
