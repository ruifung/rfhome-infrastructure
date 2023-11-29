$TALOS_VERSION = "v1.5.5"
$TALOS_FACTORY_SCHEMATIC_ID = "7c2c54e67216d672d98c72cb5c5dbc5da72c4c9ba8e308a1a7d7eb07b6ecd0e3"
# $TALOS_INSTALL_IMAGE="factory.talos.dev/installer/${TALOS_FACTORY_SCHEMATIC_ID}:${TALOS_VERSION}"
$TALOS_INSTALL_IMAGE = "harbor.services.home.yrf.me/talos-image-factory/installer/${TALOS_FACTORY_SCHEMATIC_ID}:${TALOS_VERSION}"
 
$homeDnsSuffix = "servers.home.yrf.me"
$mode, $extraArgs = $args
$extraArgs = $extraArgs -join " "

$controlplane = @(
    "pathweb-control-1.$homeDnsSuffix",
    "pathweb-control-2.$homeDnsSuffix",
    "pathweb-control-3.$homeDnsSuffix"
)

$workers = @(
    "pathweb-worker-1.$homeDnsSuffix",
    "pathweb-worker-2.$homeDnsSuffix",
    "pathweb-worker-3.$homeDnsSuffix"
)

Write-Output "Extra Args: $extraArgs"
$toApply = @()
if (($mode -eq "controlplane") -or ($mode -eq "all")) {
    $toApply = $toApply + $controlplane
}
if (($mode -eq "workers") -or ($mode -eq "all")) {
    $toApply = $toApply + $workers
}
#if toApply is empty, split mode by comma and append result to toApply after trimming excess whitespace
if ($toApply.Count -eq 0) {
    $toApply = $mode.Split(',') | ForEach-Object { $_.Trim() }
}

foreach ($node in $toApply) {
    $IMAGE = $TALOS_INSTALL_IMAGE
    Write-Output "Upgrading node [$($node)] to Talos version [$TALOS_VERSION] using install image [$IMAGE]"
    $talosctlArgs = @(
        'upgrade',
        '--nodes',
        $node,
        '--image',
        $IMAGE,
        '--wait'
        # '--stage'
    )
    # append extraArgs to args if extraArgs is not blank
    if ($extraArgs -ne "") {
        $talosctlArgs = $talosctlArgs + $extraArgs.Split(' ')
    }

    function Get-TalosNodeVersion {
        param (
            [Parameter(Mandatory = $true)]
            [string]$node
        )
        $versionOutput = $(talosctl version --nodes $node --short) -join ""
        if ($LASTEXITCODE -eq 0 && $versionOutput -match 'Server:[\s\S\n]*Tag:\s*(v\d+\.\d\.\d)' && $Matches -ne $null) {
            return $Matches[1]
        }
        else {
            throw "Failed to get Talos version for node [$node]"
        }
    }

    # attempt upgrade until successful
    $success = $false
    while ($success -eq $false) {
        # skip upgrade if node is already target version
        $version = Get-TalosNodeVersion $node
        if ($version -eq $TALOS_VERSION) {
            Write-Output "Node [$node] is already at Talos version [$version], skipping upgrade"
            $success = $true
            continue
        }
        talosctl $talosctlArgs
        $success = ($LASTEXITCODE -eq 0)
        if ($success) {
            $version = Get-TalosNodeVersion $node
            # retry upgrade if version upgrade failed
            if ($version -ne $TALOS_VERSION) {
                Write-Output "Talos version [$version] does not match expected version [$TALOS_VERSION], retrying upgrade"
                $success = $false
            } else {
                Write-Output "Successfully upgraded node [$node] to Talos version [$version]"
            }
        }
        # Write-Output "Waiting for cilium on [$node] to become ready"
        # cilium status --wait --wait-duration 24h

        # resolve node domain to IP address if required
        # if ($node -match '^[a-zA-Z0-9\-\.]+$') {
            # $node = [System.Net.Dns]::GetHostAddresses($node) | Where-Object { $_.AddressFamily -eq 'InterNetwork' } | Select-Object -First 1 -ExpandProperty IPAddressToString
        # }
        # find node in kubernetes with matching IP
        # $node = kubectl get nodes -o jsonpath="{.items[?(@.status.addresses[?(@.type=='InternalIP')].address=='$node')].metadata.name}"

        # wait for node to be ready
        # Write-Output "Waiting for node [$node] to become ready"
        # kubectl wait --for=condition=Ready node/$node --timeout=24h
        
    }
}