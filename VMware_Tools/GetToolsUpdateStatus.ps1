$VMs = Get-VM -Name (Get-Content .\ServerList.txt)
foreach ($VM in $VMs) {
    $VM | ForEach-Object {Get-View $_.id} | Where-Object {$_.Guest.ToolsVersionStatus2 -ne "guestToolsCurrent"} | Select-Object Name, Server, @{Name="VMware Tools Version"; Expression={$_.config.tools.toolsVersion}}, @{Name="VMware Tools Status"; Expression={$_.Guest.ToolsVersionStatus2}} | Export-Csv .\VMToolsUpdate.csv -Append -NoTypeInformation
}
