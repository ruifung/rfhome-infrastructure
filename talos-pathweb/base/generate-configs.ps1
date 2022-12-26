talosctl gen config pathweb "https://10.229.17.1:6443" --output-dir _out --config-patch @node-patches.yaml --config-patch-control-plane @controlplane-patches.yaml
talosctl --talosconfig .\_out\talosconfig config endpoint 10.229.17.1
Move-Item .\_out\controlplane.yaml .\controlplane.yaml
Move-Item .\_out\worker.yaml .\worker.yaml
Move-Item .\_out\talosconfig ..\talosconfig
Remove-Item _out