.\apply-config.ps1 all --insecure
Write-Host "Bootstrapping Talos Cluster"
talosctl bootstrap --talosconfig .\talosconfig --nodes pathweb-control-1.servers.home.yrf.me
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
Write-Host "Generating Kubeconfig"
talosctl --talosconfig .\talosconfig -n pathweb-control-1.servers.home.yrf.me kubeconfig .
talosctl --talosconfig .\talosconfig -n pathweb-control-1.servers.home.yrf.me kubeconfig $env:USERPROFILE\.kube\config
$Env:KUBECONFIG = Resolve-Path .\kubeconfig
Write-Host "Installing cilium"
#helm repo add cilium https://helm.cilium.io/
#helm install cilium cilium/cilium --namespace kube-system -f cilium-values.yaml
# Requires Cilium CLI 1.15 or newer using helm mode.
cilium install --values cilium-values.yaml --wait --namespace kube-system
# Write-Host "Waiting for cilium to be ready."
# cilium status --wait