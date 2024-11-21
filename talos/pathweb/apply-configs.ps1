$ErrorActionPreference = "Stop"

$mode, $extraArgs = $args
$extraArgs = $extraArgs -join " "

$nodes = Get-Content nodes.json -Raw | ConvertFrom-Json | Where-Object {$_.ignore -ne $true}

if ($null -eq $mode) {
    Write-Error "No mode specified. Specify either a node or one of the following: controlplane, workers, all"
    Exit
}

if (-not ($extraArgs -like "*--mode*")) { $extraArgs = "--mode try $extraArgs"}
Write-Output "Extra Args: $extraArgs"
$toApply = @()
# Apply the workers first and controlplane last.
if (($mode -eq "workers") -or ($mode -eq "all")) {
    $toApply = $toApply + ($nodes | Where-Object {$_.role -eq "worker"})
}
if (($mode -eq "controlplane") -or ($mode -eq "all")) {
    $toApply = $toApply + ($nodes | Where-Object {$_.role -eq "controlplane"})
}

#if toApply is empty, split mode by comma and append result to toApply after trimming excess whitespace
if ($toApply.Count -eq 0) {
    $targets = $mode.Split(',') | Where-Object { $_ -ne "" }
    # filter toApply by fqdn in $targets
    $toApply = $nodes | Where-Object {
        $node = $_
        ($targets -contains $node.fqdn) -or (($targets | Where-Object { $node.fqdn.StartsWith("$_.") }).Count -gt 0)
    }
}
# if toApply is still empty, print out all available fqdns
if ($toApply.Count -eq 0) {
    Write-Output "No nodes found for mode [$mode]"
    Write-Output "Available nodes:"
    Write-Output "controlplane: $(($nodes | Where-Object {$_.role -eq "controlplane"}).fqdn -join ', ')"
    Write-Output "workers: $(($nodes | Where-Object {$_.role -eq "worker"}).fqdn -join ', ')"
    exit 1
}

foreach ($node in $toApply) {
    Write-Output "Applying configuration for node: $($node.fqdn)"
    $bootstrapIpPattern = "--bootstrap-ip=([a-fA-F0-9:.]+)+"
    $targetNode = $node.fqdn
    $bootstrapIp = ""

    if ($extraArgs.Contains("--insecure") -and $extraArgs -match $bootstrapIpPattern) {
        $bootstrapIp = ($extraArgs | Select-String -Pattern $bootstrapIpPattern).Matches.Groups[1].Value
        $extraArgs = $extraArgs -replace $bootstrapIpPattern,"-e $bootstrapIp"
        $targetNode = $bootstrapIp
        Write-Output "Uploading initial config to node at address: $bootstrapIp"
    }


    $machineConfigFile = ".\machineconfig\$($node.fqdn).yaml"

    $extraArgs = $extraArgs -split " " | Where-Object { $_ -ne "" }
    if ($targetNode -ne "") {
        Write-Output "> talosctl apply-config --talosconfig .\talosconfig --nodes $($targetNode) --file $($machineConfigFile) $extraArgs"
        talosctl apply-config --talosconfig .\talosconfig --nodes $($targetNode) --file $($machineConfigFile) @extraArgs
        if ($LASTEXITCODE -ne 0) {
            Write-Error "talosctl exited with exit code $LASTEXITCODE"
            Exit
        }
    }
    Write-Output ""
}
