$TALOS_VERSION = "v1.6.1"
$TALOS_FACTORY_SCHEMATIC_ID = "20f0f58646bf4fbb1f4f4256484fbf4955dde1f0baf46306834b6ebdda71128d"
# $TALOS_INSTALL_IMAGE="factory.talos.dev/installer/${TALOS_FACTORY_SCHEMATIC_ID}:${TALOS_VERSION}"
$TALOS_INSTALL_IMAGE = "harbor.services.home.yrf.me/talos-image-factory/installer/${TALOS_FACTORY_SCHEMATIC_ID}:${TALOS_VERSION}"
 
$homeDnsSuffix = "servers.home.yrf.me"
$mode, $extraArgs = $args
$extraArgs = $extraArgs -join " "

$controlplane = @(
    "talos-harbor.$homeDnsSuffix"
)

$workers = @()

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
        '--preserve'
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
        # $version = Get-TalosNodeVersion $node
        # if ($version -eq $TALOS_VERSION) {
        #     Write-Output "Node [$node] is already at Talos version [$version], skipping upgrade"
        #     $success = $true
        #     continue
        # }
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
        
    }
}