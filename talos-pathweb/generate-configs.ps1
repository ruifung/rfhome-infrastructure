Push-Location base
talosctl gen config pathweb "https://10.229.17.1:6443" --output-dir _out --with-secrets secrets.yaml
talosctl --talosconfig .\_out\talosconfig config endpoint 10.229.17.1
talosctl --talosconfig .\_out\talosconfig config endpoint 10.229.17.1 10.229.17.2 10.229.17.3
talosctl --talosconfig .\_out\talosconfig config node 10.229.17.1 10.229.17.2 10.229.17.3 10.229.17.4 10.229.17.5 10.229.17.6
Move-Item .\_out\controlplane.yaml .\controlplane.yaml -Force
Move-Item .\_out\worker.yaml .\worker.yaml -Force
Move-Item .\_out\talosconfig ..\talosconfig -Force
Remove-Item _out
Pop-Location