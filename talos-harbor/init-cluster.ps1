Write-Host "Bootstrapping Talos Cluster"
talosctl bootstrap --talosconfig .\talosconfig --nodes talos-harbor.servers.home.yrf.me
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
} until(Check-ApiServer "https://talos-harbor.servers.home.yrf.me:6443")
Write-Host "Generating Kubeconfig"
talosctl --talosconfig .\talosconfig -n talos-harbor.servers.home.yrf.me kubeconfig .
talosctl --talosconfig .\talosconfig -n talos-harbor.servers.home.yrf.me kubeconfig $env:USERPROFILE\.kube\config
$Env:KUBECONFIG = Resolve-Path .\kubeconfig