<#
Current Talos Image Factory Configuration
-----------------------------------------
customization:
    extraKernelArgs:
        - net.ifnames=0
    systemExtensions:
        officialExtensions:
            - siderolabs/binfmt-misc
            - siderolabs/fuse3
            - siderolabs/gvisor
            - siderolabs/iscsi-tools
            - siderolabs/kata-containers
            - siderolabs/qemu-guest-agent
            - siderolabs/wasmedge
------------------------------------------
Pi Node Image Factory C0nfiguration
------------------------------------------
overlay:
    image: siderolabs/sbc-raspberrypi
    name: rpi_generic
customization:
    systemExtensions:
        officialExtensions:
            - siderolabs/binfmt-misc
            - siderolabs/fuse3
            - siderolabs/gvisor
            - siderolabs/iscsi-tools
            - siderolabs/kata-containers
            - siderolabs/wasmedge
#>
$KUBE_CTX = "admin@pathweb"
$TALOS_VERSION = "v1.7.1"
$TALOS_FACTORY_SCHEMATIC_ID = "ff4c7c9e75f037073e593e00f43c862d66f98a465f5afe10fa513d4fb54b5479"
$RPI_FACTORY_SCHEMATIC_ID = "15d3da5525ae052a575d21c83c16544631b9eb7e95283eccc254ddf8eb2c4fd3"
# $TALOS_INSTALL_IMAGE="factory.talos.dev/installer/${TALOS_FACTORY_SCHEMATIC_ID}:${TALOS_VERSION}"
$TALOS_INSTALL_IMAGE = "factory.talos.dev/installer/${TALOS_FACTORY_SCHEMATIC_ID}:${TALOS_VERSION}"
$RPI_INSTALL_IMAGE = "factory.talos.dev/installer/${RPI_FACTORY_SCHEMATIC_ID}:${TALOS_VERSION}"
 
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
    "pathweb-worker-3.$homeDnsSuffix",
    "pathweb-worker-baldric.$homeDnsSuffix"
)

$piworkers = @(
    "pathweb-worker-pi4-01.$homeDnsSuffix"
)

Write-Output "Extra Args: $extraArgs"
$toApply = @()
if (($mode -eq "controlplane") -or ($mode -eq "all")) {
    $toApply = $toApply + $controlplane
}
if (($mode -eq "workers") -or ($mode -eq "all")) {
    $toApply = $toApply + $workers + $piworkers
}
#if toApply is empty, split mode by comma and append result to toApply after trimming excess whitespace
if ($toApply.Count -eq 0) {
    $toApply = $mode.Split(',') | ForEach-Object { $_.Trim() }
}

foreach ($node in $toApply) {
    Write-Output "Preparing to upgrade node [$node]"
    $SCHEMATIC = $TALOS_FACTORY_SCHEMATIC_ID
    $IMAGE = $TALOS_INSTALL_IMAGE
    if ($piworkers.Contains($node)) {
        Write-Output "Upgrading Listed RPi Node. Using RPi options."
        $SCHEMATIC = $RPI_FACTORY_SCHEMATIC_ID
        $IMAGE = $RPI_INSTALL_IMAGE
    }
    $talosctlArgs = @(
        'upgrade',
        '--nodes',
        $node,
        '--image',
        $IMAGE
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

    function Get-TalosNodeSchematic {
        param (
            [Parameter(Mandatory = $true)]
            [string]$node
        )
        $schematicExtension = talosctl get extensions --nodes $node --output yaml | ConvertFrom-Yaml -AllDocuments | Where-Object {$_.spec.metadata.name -eq "schematic" }
        if ($null -eq $schematicExtension) {
            throw "Failed to get schematic extension for node [$node]"
        }
        return $schematicExtension.spec.metadata.version
    }

    function Get-DeploymentStsReady {
        $deployments = kubectl --context=$KUBE_CTX get deployments,statefulsets -A -o json | ConvertFrom-Json
        $ready = $True
        foreach ($deployment in $deployments.items) {
            if (($null -eq $deployment.status.readyReplicas) -and ($deployment.status.replicas -eq 0)) {
                continue
            }
            if ($deployment.status.replicas -ne $deployment.status.readyReplicas) {
                $ready = $False
                break
            }
        }
        return $ready
    }

    # attempt upgrade until successful
    $success = $false
    while ($success -eq $false) {
        # skip upgrade if node is already target version
        Write-Output "Checking existing version for node [$node]"
        $version = Get-TalosNodeVersion $node
        Write-Output "Checking existing schematic for node [$node]"
        $schematic = Get-TalosNodeSchematic $node
        if (($version -eq $TALOS_VERSION) -and ($schematic -eq $SCHEMATIC)) {
            Write-Output "Node [$node] is already at Talos version [$version], schematic [$schematic], skipping upgrade."
            $success = $true
            continue
        }
        Write-Output "Upgrading node [$node] to Talos version [$TALOS_VERSION], schematic [$SCHEMATIC]."
        Write-Output "Current version is [$version], current schematic is [$schematic]"
        Write-Output "Using image: [$IMAGE]"
        talosctl $talosctlArgs
        $success = ($LASTEXITCODE -eq 0)
        if ($success -and (-not ($controlplane.Contains($node)))) {
            $version = Get-TalosNodeVersion $node
            $schematic = Get-TalosNodeSchematic $node
            # retry upgrade if version upgrade failed
            if ($version -ne $TALOS_VERSION) {
                Write-Output "Talos version [$version] does not match expected version [$TALOS_VERSION], retrying upgrade"
                $success = $false
            } elseif ($schematic -ne $SCHEMATIC) {
                Write-Output "Talos schematic [$schematic] does not match expected schematic [$SCHEMATIC], retrying upgrade"
                $success = $false
            } else {
                Write-Output "Successfully upgraded node [$node] to Talos version [$version]"
            }
            while(!(Get-DeploymentStsReady)) {
                Write-Output "Deployment or StatefulSet not ready, sleeping for 5 seconds."
                Start-Sleep -Seconds 5
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