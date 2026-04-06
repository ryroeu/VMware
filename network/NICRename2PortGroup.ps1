### will change the guest OS adapter name to correspond with the PortGroup the vNIC is connected to ###
$code = @'
Get-NetAdapterHardwareInfo | Select-Object Name, Slot, @{N='Mac';E={Get-NetAdapter -Name $_.Name | Select-Object -ExpandProperty MacAddress}} | ConvertTo-Csv -NoTypeInformation -UseCulture
'@
$changeAdapterName = @'
Rename-NetAdapter -Name '#oldname#' -NewName '#newname#' -Confirm:$false
'@
Get-VM | Where-Object {$_.PowerState -eq 'PoweredOn' -and $_.ExtensionData.COnfig.GuestFullName -match 'Windows'} | ForEach-Object {
    $osPCI = Invoke-VMScript -VM $_ -ScriptText $code -ScriptType Powershell | Select-Object -ExpandProperty ScriptOutput | ConvertFrom-Csv
    foreach ($vnic in Get-NetworkAdapter -VM $_){
        $osNic = $osPCI | Where-Object {$_.slot -eq $vnic.ExtensionData.SlotINfo.PciSlotNumber}
        if($osNic){
            if($osNic.Name -ne $vnic.NetworkName){
                $codeAdapter = $changeAdapterName.Replace('#oldname#',$osNic.Name).Replace('#newname#',$vnic.NetworkName)
                Invoke-VMScript -VM $_ -ScriptText $codeAdapter -ScriptType Powershell
            }
        }
    }
}