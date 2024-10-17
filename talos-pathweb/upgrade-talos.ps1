<#
Current Talos Image Factory Configuration
-----------------------------------------
customization:
    extraKernelArgs:
        - net.ifnames=0
    systemExtensions:
        officialExtensions:
            - siderolabs/fuse3
            - siderolabs/gvisor
            - siderolabs/iscsi-tools
            - siderolabs/qemu-guest-agent
------------------------------------------
Pi Node Image Factory C0nfiguration
------------------------------------------
overlay:
    image: siderolabs/sbc-raspberrypi
    name: rpi_generic
customization:
    extraKernelArgs:
        - net.ifnames=0
    systemExtensions:
        officialExtensions:
            - siderolabs/fuse3
            - siderolabs/gvisor
            - siderolabs/iscsi-tools
#>
$KUBE_CTX = "admin@pathweb"

$mode, $extraArgs = $args
if ($null -ne $extraArgs) {
    $force = $extraArgs.Contains("--force")
    $extraArgs = $extraArgs.Remove($extraArgs.IndexOf("--force"))
}

$nodes = Get-Content nodes.json -Raw | ConvertFrom-Json | Where-Object { $_.ignore -ne $true }
$versions = Get-Content talos-version.json -Raw | ConvertFrom-Json 

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
    $schematicExtension = talosctl get extensions --nodes $node --output yaml | ConvertFrom-Yaml -AllDocuments | Where-Object { $_.spec.metadata.name -eq "schematic" }
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to get Talos schematic for node [$node]"
    }
    if ($null -eq $schematicExtension) {
        return $null
    }
    return $schematicExtension.spec.metadata.version
}

function Get-DeploymentStsReady {
    $deployments = kubectl --context=$KUBE_CTX get deployments, statefulsets -A -o json | ConvertFrom-Json
    $ready = $True
    foreach ($deployment in $deployments.items) {
        if (($deployment.status.replicas -eq 0) -or ($null -eq $deployment.status.readyReplicas)) {
            continue
        }
        if ($deployment.status.replicas -ne $deployment.status.readyReplicas) {
            $ready = $False
            break
        }
    }
    return $ready
}

function Start-SleepWithProgress {
    param (
        [Parameter(Mandatory = $true)]
        [string]$message,
        [Parameter(Mandatory = $true)]
        [int]$seconds
    )
    $count = 0
    while ($count -lt $seconds) {
        Write-Progress $message -SecondsRemaining $($seconds-$count) -PercentComplete ($count/$seconds)*100
        $count += 1
        Start-Sleep -Seconds 1
    }
}

function Wait-ForDeploymentStsReady {
    while(!(Get-DeploymentStsReady)) {
        Start-SleepWithProgress "Waiting for all Deployments or StatefulSets to be ready." 5
    }
}

function Confirm-TalosVersionAndSchematic {
    param (
        [Parameter(Mandatory = $true)]
        [string]$node,
        [Parameter(Mandatory = $true)]
        [string]$expectedVersion,
        [Parameter(Mandatory = $true)]
        [string]$expectedSchematic,
        [Parameter(Mandatory = $false)]
        [ref]$currentVersionRef,
        [Parameter(Mandatory = $false)]
        [ref]$currentSchematicRef
    )
    $currentVersion = Get-TalosNodeVersion $node
    $currentSchematic = Get-TalosNodeSchematic $node

    if ($null -ne $currentVersionRef) {
        $currentVersionRef.Value = $currentVersion
    }
    if ($null -ne $currentSchematicRef) {
        $currentSchematicRef.Value = $currentSchematic
    }

    $versionMatch = $expectedVersion -eq $currentVersion
    $schematicMatch = $expectedSchematic -eq $currentSchematic

    return $versionMatch -and $schematicMatch
}

function Invoke-TalosNodeUpgrade {
    param (
        [Parameter(Mandatory = $true)]
        [string]$node,
        [Parameter(Mandatory = $true)]
        [string]$role,
        [Parameter(Mandatory = $true)]
        [string]$image,
        [Parameter(Mandatory = $true)]
        [string]$imageVersion,
        [Parameter(Mandatory = $false)]
        [string]$imageSchematic
    )
    $talosctlArgs = @(
        'upgrade',
        '--talosconfig',
        '.\talosconfig',
        '--nodes',
        $node,
        '--image',
        $image
        # '--stage'
    )
    # append extraArgs to args if extraArgs is not blank
    if ($extraArgs -ne "") {
        $talosctlArgs = $talosctlArgs + $extraArgs 
    }


    $success = $false
    while ($success -eq $false) {
        try {
            $currentVersion = $null
            $currentSchematic = $null
            if (Confirm-TalosVersionAndSchematic $node $imageVersion $imageSchematic ([ref]$currentVersion) ([ref]$currentSchematic)) {
                if (-not $force) {
                    Write-Output "Node [$node] is already at Talos version [$imageVersion], schematic [$imageSchematic], skipping upgrade."
                    $success = $true
                    continue
                }
            }

            Write-Output "Upgrading node [$node] to Talos version [$imageVersion], schematic [$imageSchematic]."
            Write-Output "Current version: $currentVersion"
            Write-Output "Current schematic: $currentSchematic"
            talosctl $talosctlArgs
            $success = $LASTEXITCODE -eq 0
            if ($success) {
                $success = Confirm-TalosVersionAndSchematic $node $imageVersion $imageSchematic ([ref]$currentVersion) ([ref]$currentSchematic)
                if (-not $success) {
                    Write-Output "Post-upgrade version: $currentVersion"
                    Write-Output "Post-upgrade schematic: $currentSchematic"
                    Write-Output "Post-upgrade version/schematic mismatch. Retrying upgrade."
                    continue
                } else {
                    Write-Output "Node [$node] successfully upgraded to Talos version [$imageVersion], schematic [$imageSchematic]."
                }


                if ($role -ne "controlplane") {
                    Wait-ForDeploymentStsReady
                }
            }
        }
        catch {
            Start-SleepWithProgress "Failed to perform upgrade. Retry in 10 seconds." 10
            continue
        }
    }
}

foreach ($node in $nodes) {
    $upgradeThisNode = $false
    if ($mode -eq "all:") { $upgradeThisNode = $true }
    if ($mode -eq "role:$($node.role)") { $upgradeThisNode = $true }
    if ($mode -eq "type:$($node.type)") { $upgradeThisNode = $true }
    if ($node.fqdn.StartsWith($mode)) { $upgradeThisNode = $true }
    if (-not $upgradeThisNode) { continue }

    Write-Output "Preparing to upgrade node [$($node.fqdn)]"
    Write-Output "Node Type: $($node.type)"
    Write-Output "Node Role: $($node.role)"
    $VERSION = $versions.version
    if ($versions.image_override.$($node.type) -is [string]) {
        $SCHEMATIC = $null
        $IMAGE = $versions.image_override.$($node.type)
    }
    else {
        $SCHEMATIC = $versions.schematics.$($node.type)
        $IMAGE = "$($versions.factory_image_registry)/installer/${SCHEMATIC}:${VERSION}"
    }
    Write-Output "Version: $VERSION"
    if ($null -ne $SCHEMATIC) {
        Write-Output "Schematic: $SCHEMATIC"
    }
    Write-Output "Image: $IMAGE"

    Invoke-TalosNodeUpgrade $node.fqdn $node.role $IMAGE $VERSION $SCHEMATIC
}