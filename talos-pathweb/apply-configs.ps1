$mode, $extraArgs = $args
$extraArgs = $extraArgs -join " "
$dnsSuffix = "pathweb.clusters.home.yrf.me"
Write-Output "Extra Args: $extraArgs"
if ($extraArgs -eq "") { $extraArgs = "--mode=auto" }
if (($mode -eq "controlplane") -or ($mode -eq "all")) {
    Write-Output "Applying control-plane machine configs."
    talosctl apply-config --talosconfig .\talosconfig --nodes 1.controlplane.$dnsSuffix --file .\base\controlplane.yaml -p @patches\node-patches.yaml,@patches\controlplane-patches.yaml,@patches\control-1.yaml $extraArgs
    talosctl apply-config --talosconfig .\talosconfig --nodes 2.controlplane.$dnsSuffix --file .\base\controlplane.yaml -p @patches\node-patches.yaml,@patches\controlplane-patches.yaml,@patches\control-2.yaml $extraArgs
    talosctl apply-config --talosconfig .\talosconfig --nodes 3.controlplane.$dnsSuffix --file .\base\controlplane.yaml -p @patches\node-patches.yaml,@patches\controlplane-patches.yaml,@patches\control-3.yaml $extraArgs
}
if (($mode -eq "worker") -or ($mode -eq "all")) {
    Write-Output "Applying worker-nodes machine configs."
    talosctl apply-config --talosconfig .\talosconfig --nodes 10.229.97.34 --file .\base\worker.yaml -p @patches\node-patches.yaml,@patches\worker-patches.yaml,@patches\worker-1.yaml $extraArgs
    talosctl apply-config --talosconfig .\talosconfig --nodes 10.229.97.35 --file .\base\worker.yaml -p @patches\node-patches.yaml,@patches\worker-patches.yaml,@patches\worker-2.yaml $extraArgs
    talosctl apply-config --talosconfig .\talosconfig --nodes 10.229.97.36 --file .\base\worker.yaml -p @patches\node-patches.yaml,@patches\worker-patches.yaml,@patches\worker-3.yaml $extraArgs
}