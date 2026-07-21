### to create the mapping between vNICs and adapters in the (Windows) guest OS ###
$code = @'
Get-NetAdapterHardwareInfo | Select-Object Name, Slot, @{N='mac';E={Get-NetAdapter -Name $_.Name | Select-Object -ExpandProperty MacAddress}} | ConvertTo-Csv -NoTypeInformation -UseCulture
'@
Get-VM | Where-Object {$_.PowerState -eq 'PoweredOn' -and $_.ExtensionData.COnfig.GuestFullName -match 'Windows'} | ForEach-Object {
    $osPCI = Invoke-VMScript -VM $_ -ScriptText $code -ScriptType Powershell | Select-Object -ExpandProperty ScriptOutput | ConvertFrom-Csv
    foreach ($vnic in Get-NetworkAdapter -VM $_){
        $osNic = $osPCI | Where-Object {$_.slot -eq $vnic.ExtensionData.SlotINfo.PciSlotNumber}
        New-Object PSObject -Property ([ordered]@{
            VM = $_.Name
            Portgroup = $vnic.NetworkName
            vMAC = $vnic.MacAddress
            osMAC = $osNic.mac
            vNIC = $vnic.Name
            osNIC = $osNic.name
            vSlot = $vnic.ExtensionData.SlotINfo.PciSlotNumber
            osSlot = $osNic.Slot
        })
    }
}