# Update-Tools is available in current PowerCLI releases.
# Use the supported cmdlet with -NoReboot instead of calling the vSphere API directly.

Get-VM -Name * | Where-Object {$_.PowerState -eq "PoweredOn"} | ForEach-Object {
    Write-Host "Upgrading VMware Tools on $($_.Name)..."
    $_ | Update-Tools -NoReboot
}
