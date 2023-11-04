$TALOS_VERSION="v1.5.4"
$TALOS_FACTORY_SCHEMATIC_ID="8e8827b5b91420728f8415f3dc200fbf23b425ec07bf27cdc92a676367ee9edf"
$TALOS_FACTORY_CLOUD_SCHEMATIC_ID="d9ff89777e246792e7642abd3220a616afb4e49822382e4213a2e528ab826fe5"
$TALOS_INSTALL_IMAGE="factory.talos.dev/installer/${TALOS_FACTORY_SCHEMATIC_ID}:${TALOS_VERSION}"
$TALOS_CLOUD_IMAGE="factory.talos.dev/installer/${TALOS_FACTORY_CLOUD_SCHEMATIC_ID}:${TALOS_VERSION}"

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

$cloudworkers = @(
    'cloud-1.pathweb.0spkl.dev'
)



Write-Output "Extra Args: $extraArgs"
$toApply = @()
if (($mode -eq "controlplane") -or ($mode -eq "all")) {
    $toApply = $toApply + $controlplane
}
if (($mode -eq "workers") -or ($mode -eq "all")) {
    $toApply = $toApply + $workers
}
if (($mode -eq "cloud") -or ($mode -eq "all")) {
    $toApply = $toApply + $cloudworkers
}
#if toApply is empty, split mode by comma and append result to toApply after trimming excess whitespace
if ($toApply.Count -eq 0) {
    $toApply = $mode.Split(',') | ForEach-Object { $_.Trim() }
}

$failedNodes = @()
foreach ($node in $toApply) {
    $IMAGE=$TALOS_INSTALL_IMAGE
    # if node is in cloudworkers use cloud image instead
    if ($cloudworkers -contains $node) {
        $IMAGE=$TALOS_CLOUD_IMAGE
    }
    Write-Output "Upgrading node [$($node)] to Talos version [$TALOS_VERSION] using install image [$IMAGE]"
    $args = @(
        'upgrade',
        '--nodes',
        $node,
        '--image',
        $IMAGE,
        '--wait'
    )
    # append extraArgs to args if extraArgs is not blank
    if ($extraArgs -ne "") {
        $args = $args + $extraArgs.Split(' ')
    }

    talosctl $args

    #retry upgrade once if command fails
    if ($LASTEXITCODE -ne 0) {
        Write-Output "Upgrade failed, retrying..."
        talosctl $args
    }

    #if command fails again, store node for logging later
    if ($LASTEXITCODE -ne 0) {
        Write-Output "Upgrade failed again, storing node for logging later"
        $failedNodes = $failedNodes + $node
    }
}

# log failed nodes
if ($failedNodes.Count -gt 0) {
    Write-Output "Upgrade failed for the following nodes:"
    $failedNodes | ForEach-Object { Write-Output $_ }
}
