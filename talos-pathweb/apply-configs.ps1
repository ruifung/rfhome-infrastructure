$mode, $extraArgs = $args
$extraArgs = $extraArgs -join " "
$homeDnsSuffix = "servers.home.yrf.me"
$controlplane = @(
    @{
        fqdn = "pathweb-control-1.$homeDnsSuffix";
        base = '.\base\controlplane.yaml';
        patches = @('@patches\node-patches.yaml','@patches\controlplane-patches.yaml','@patches\control-1.yaml', '@patches\harbor-rfhome.secret.yaml')
    },
    @{
        fqdn = "pathweb-control-2.$homeDnsSuffix";
        base = '.\base\controlplane.yaml';
        patches = @('@patches\node-patches.yaml','@patches\controlplane-patches.yaml','@patches\control-2.yaml', '@patches\harbor-rfhome.secret.yaml')
    },
    @{
        fqdn = "pathweb-control-3.$homeDnsSuffix";
        base = '.\base\controlplane.yaml';
        patches = @('@patches\node-patches.yaml','@patches\controlplane-patches.yaml','@patches\control-3.yaml', '@patches\harbor-rfhome.secret.yaml')
    }
)
$workers = @(
    @{
        fqdn = "pathweb-worker-1.$homeDnsSuffix";
        base = '.\base\worker.yaml';
        patches = @('@patches\node-patches.yaml','@patches\worker-patches.yaml','@patches\worker-1.yaml', '@patches\harbor-rfhome.secret.yaml')
    },
    @{
        fqdn = "pathweb-worker-2.$homeDnsSuffix";
        base = '.\base\worker.yaml';
        patches = @('@patches\node-patches.yaml','@patches\worker-patches.yaml','@patches\worker-2.yaml', '@patches\harbor-rfhome.secret.yaml')
    },
    @{
        fqdn = "pathweb-worker-3.$homeDnsSuffix";
        base = '.\base\worker.yaml';
        patches = @('@patches\node-patches.yaml','@patches\worker-patches.yaml','@patches\worker-3.yaml', '@patches\harbor-rfhome.secret.yaml')
    }
    # @{
    #     fqdn = 'pathweb-piworker-1.vsvc.home.arpa';
    #     base = '.\base\worker.yaml';
    #     patches = @('@patches\node-patches.yaml','@patches\pi-worker.yaml','@patches\piworker-1.yaml')
    # }
)
$cloudworkers = @(
    @{
        fqdn = 'cloud-1.pathweb.0spkl.dev';
        base = '.\base\worker.yaml';
        patches = @('@patches\cloud-node-patches.yaml','@vultr-cloud\vultr-worker.yaml','@vultr-cloud\cloud-1.yaml')
    }
)

Write-Output "Extra Args: $extraArgs"
if ($extraArgs -eq "") { $extraArgs = "--mode=auto" }
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
    $targets = $mode.Split(',')
    $toApply = $controlplane + $workers + $cloudworkers
    # filter toApply by fqdn in $targets
    $toApply = $toApply | Where-Object { $targets -contains $_.fqdn } 
}
# if toApply is still empty, print out all available fqdns
if ($toApply.Count -eq 0) {
    Write-Output "No nodes found for mode [$mode]"
    Write-Output "Available nodes:"
    Write-Output "controlplane: $($controlplane.fqdn -join ', ')"
    Write-Output "workers: $($workers.fqdn -join ', ')"
    Write-Output "cloud: $($cloudworkers.fqdn -join ', ')"
    exit 1
}

foreach ($node in $toApply) {
    Write-Output "Applying configuration for node: $($node.fqdn)"
    talosctl apply-config --talosconfig .\talosconfig --nodes $($node.fqdn) --file $($node.base) -p $($node.patches -join ',') $extraArgs
}