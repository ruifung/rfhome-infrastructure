$mode, $extraArgs = $args
$extraArgs = $extraArgs -join " "
$homeDnsSuffix = "pathweb.clusters.home.yrf.me"
$controlplane = @(
    @{
        fqdn = "1.controlplane.$homeDnsSuffix";
        base = '.\base\controlplane.yaml';
        patches = @('@patches\node-patches.yaml','@patches\controlplane-patches.yaml','@patches\control-1.yaml')
    },
    @{
        fqdn = "2.controlplane.$homeDnsSuffix";
        base = '.\base\controlplane.yaml';
        patches = @('@patches\node-patches.yaml','@patches\controlplane-patches.yaml','@patches\control-2.yaml')
    },
    @{
        fqdn = "3.controlplane.$homeDnsSuffix";
        base = '.\base\controlplane.yaml';
        patches = @('@patches\node-patches.yaml','@patches\controlplane-patches.yaml','@patches\control-3.yaml')
    }
)
$workers = @(
    @{
        fqdn = "10.229.17.4";
        base = '.\base\worker.yaml';
        patches = @('@patches\node-patches.yaml','@patches\worker-patches.yaml','@patches\worker-1.yaml')
    },
    @{
        fqdn = "10.229.17.5";
        base = '.\base\worker.yaml';
        patches = @('@patches\node-patches.yaml','@patches\worker-patches.yaml','@patches\worker-2.yaml')
    },
    @{
        fqdn = "10.229.17.6";
        base = '.\base\worker.yaml';
        patches = @('@patches\node-patches.yaml','@patches\worker-patches.yaml','@patches\worker-3.yaml')
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

foreach ($node in $toApply) {
    Write-Output "Applying configuration for node: $($node.fqdn)"
    talosctl apply-config --talosconfig .\talosconfig --nodes $($node.fqdn) --file $($node.base) -p $($node.patches -join ',') $extraArgs
}