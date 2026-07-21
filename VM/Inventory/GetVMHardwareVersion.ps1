$VMs = Get-VM
foreach ($VM in $VMs) {
    $VM | Select-Object Name, HardwareVersion | Export-Csv -Path .\VMHardwareVersion.csv -NoTypeInformation -Append
}