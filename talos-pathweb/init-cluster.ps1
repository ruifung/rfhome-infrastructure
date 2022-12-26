Write-Host "Applying control-plane machine configs."
talosctl apply-config --talosconfig .\talosconfig --nodes 10.229.17.1 --file .\base\controlplane.yaml -p @patches\control-1.yaml --insecure
talosctl apply-config --talosconfig .\talosconfig --nodes 10.229.17.2 --file .\base\controlplane.yaml -p @patches\control-2.yaml --insecure
talosctl apply-config --talosconfig .\talosconfig --nodes 10.229.17.3 --file .\base\controlplane.yaml -p @patches\control-3.yaml --insecure
Write-Host "Applying worker-nodes machine configs."
talosctl apply-config --talosconfig .\talosconfig --nodes 10.229.17.4 --file .\base\worker.yaml -p @patches\worker-1.yaml --insecure
talosctl apply-config --talosconfig .\talosconfig --nodes 10.229.17.5 --file .\base\worker.yaml -p @patches\worker-2.yaml --insecure
talosctl apply-config --talosconfig .\talosconfig --nodes 10.229.17.6 --file .\base\worker.yaml -p @patches\worker-3.yaml --insecure
Write-Host "Bootstrapping Talos Cluster"
talosctl bootstrap --talosconfig .\talosconfig --nodes 10.229.17.1
function Check-ApiServer([string]$Target) {     
    Try {
        Invoke-RestMethod $target -SkipCertificateCheck -SkipHttpErrorCheck
        return $True
    } catch {
        return $False
    }
}
do {
    Write-Host "Waiting for kube-apiserver to be available..."
    sleep 5
} until(Check-ApiServer "https://10.229.17.1:6443")
Write-OutWrite-Hostput "Generating Kubeconfig"
talosctl --talosconfig .\talosconfig kubeconfig .
talosctl --talosconfig .\talosconfig kubeconfig
$Env:KUBECONFIG = Resolve-Path .\kubeconfig
Write-Host "Installing cilium"
cilium install --helm-values .\cilium-values.yaml
Write-Host "Waiting for cilium to be ready."
cilium status --wait