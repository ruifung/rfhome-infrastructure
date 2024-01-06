$mode, $extraArgs = $args
$extraArgs = $extraArgs -join " "
$homeDnsSuffix = "servers.home.yrf.me"
$controlplane = @(
    @{
        fqdn = "talos-harbor.$homeDnsSuffix";
        base = '.\base\controlplane.yaml';
        patches = @('@patches\node-patches.yaml')
    }
)
$workers = @()

Write-Output "Extra Args: $extraArgs"
if ($extraArgs -eq "") { $extraArgs = "--mode=auto" }
$toApply = @()
if (($mode -eq "controlplane") -or ($mode -eq "all")) {
    $toApply = $toApply + $controlplane
}
if (($mode -eq "workers") -or ($mode -eq "all")) {
    $toApply = $toApply + $workers
}
#if toApply is empty, split mode by comma and append result to toApply after trimming excess whitespace
if ($toApply.Count -eq 0) {
    $targets = $mode.Split(',')
    $toApply = $controlplane + $workers
    # filter toApply by fqdn in $targets
    $toApply = $toApply | Where-Object { $targets -contains $_.fqdn } 
}
# if toApply is still empty, print out all available fqdns
if ($toApply.Count -eq 0) {
    Write-Output "No nodes found for mode [$mode]"
    Write-Output "Available nodes:"
    Write-Output "controlplane: $($controlplane.fqdn -join ', ')"
    Write-Output "workers: $($workers.fqdn -join ', ')"
    exit 1
}

foreach ($node in $toApply) {
    Write-Output "Applying configuration for node: $($node.fqdn)"
    talosctl apply-config --talosconfig .\talosconfig --nodes $($node.fqdn) --file $($node.base) -p $($node.patches -join ',') $extraArgs
}