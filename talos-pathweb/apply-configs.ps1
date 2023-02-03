$mode, $extraArgs = $args
$extraArgs = $extraArgs -join " "
Write-Output "Extra Args: $extraArgs"
if ($extraArgs -eq "") { $extraArgs = "--mode=auto" }
if (($mode -eq "controlplane") -or ($mode -eq "all")) {
    Write-Output "Applying control-plane machine configs."
    talosctl apply-config --talosconfig .\talosconfig --nodes 10.229.17.1 --file .\base\controlplane.yaml -p @patches\node-patches.yaml,@patches\controlplane-patches.yaml,@patches\control-1.yaml $extraArgs
    talosctl apply-config --talosconfig .\talosconfig --nodes 10.229.17.2 --file .\base\controlplane.yaml -p @patches\node-patches.yaml,@patches\controlplane-patches.yaml,@patches\control-2.yaml $extraArgs
    talosctl apply-config --talosconfig .\talosconfig --nodes 10.229.17.3 --file .\base\controlplane.yaml -p @patches\node-patches.yaml,@patches\controlplane-patches.yaml,@patches\control-3.yaml $extraArgs
}
if (($mode -eq "worker") -or ($mode -eq "all")) {
    Write-Output "Applying worker-nodes machine configs."
    talosctl apply-config --talosconfig .\talosconfig --nodes 10.229.17.4 --file .\base\worker.yaml -p @patches\node-patches.yaml,@patches\worker-patches.yaml,@patches\worker-1.yaml $extraArgs
    talosctl apply-config --talosconfig .\talosconfig --nodes 10.229.17.5 --file .\base\worker.yaml -p @patches\node-patches.yaml,@patches\worker-patches.yaml,@patches\worker-2.yaml $extraArgs
    talosctl apply-config --talosconfig .\talosconfig --nodes 10.229.17.6 --file .\base\worker.yaml -p @patches\node-patches.yaml,@patches\worker-patches.yaml,@patches\worker-3.yaml $extraArgs
}