Write-Output "Applying control-plane machine configs."
talosctl apply-config --talosconfig .\talosconfig --nodes 10.229.17.1 --file .\base\controlplane.yaml -p @patches\control-1.yaml
talosctl apply-config --talosconfig .\talosconfig --nodes 10.229.17.2 --file .\base\controlplane.yaml -p @patches\control-2.yaml
talosctl apply-config --talosconfig .\talosconfig --nodes 10.229.17.3 --file .\base\controlplane.yaml -p @patches\control-3.yaml
Write-Output "Applying worker-nodes machine configs."
talosctl apply-config --talosconfig .\talosconfig --nodes 10.229.17.4 --file .\base\worker.yaml -p @patches\worker-1.yaml
talosctl apply-config --talosconfig .\talosconfig --nodes 10.229.17.5 --file .\base\worker.yaml -p @patches\worker-2.yaml
talosctl apply-config --talosconfig .\talosconfig --nodes 10.229.17.6 --file .\base\worker.yaml -p @patches\worker-3.yaml