# Update-Tools was removed in PowerCLI 12.x.
# Use the vSphere API directly via UpgradeTools_Task().
# Passing "/S /v/qn REBOOT=R" suppresses the guest reboot (equivalent to -NoReboot).

Get-VM -Name * | Where-Object {$_.PowerState -eq "PoweredOn"} | ForEach-Object {
    Write-Host "Upgrading VMware Tools on $($_.Name)..."
    ($_ | Get-View).UpgradeTools_Task("/S /v/qn REBOOT=R")
}
