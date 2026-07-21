$VMs = Import-Csv -Path .\VMs.csv
foreach ($VM in $VMs) {
    Get-VM -Name $VM.Name | Select-Object Name, @{N='FQDN';E={$_.ExtensionData.Guest.IPStack[0].DnsConfig.HostName,$_.ExtensionData.Guest.IPStack[0].DnsConfig.DomainName -join '.'}} | Export-Csv -Path .\FQDN.csv -Append -NoTypeInformation
}