$VMs = Get-VM
foreach ($VM in $VMs) {
    $VMName = $VM.Name
    $CDDrive = $VM | Get-CDDrive
    $ISOPath = $CDDrive.ISOPath
    if ($ISOPath) {
        Write-Host "$VMName has ISO mounted: $ISOPath"
        Select-Object -InputObject $VMName -Property @{Name="VMName";Expression={$VMName}},@{Name="ISOPath";Expression={$ISOPath}} | Export-Csv -Path .\MountedISOs.csv -Append -NoTypeInformation
    }
}