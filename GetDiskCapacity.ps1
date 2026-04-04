$FinalResult = @()
$VMs = Get-View -ViewType "VirtualMachine" #-Filter @{"Runtime.PowerState"="PoweredOn"}
foreach ($VM in $VMs){
    $totalCapacity = $totalFree = 0
    $vm.Guest.Disk | ForEach-Object{
        $object = New-Object -TypeName PSObject
        $Capacity = "{0:N0}" -f [math]::Round($_.Capacity/1GB)
        $totalCapacity += $_.Capacity
        $totalFree += $_.FreeSpace
        $Freespace = "{0:N0}" -f [math]::Round($_.FreeSpace/1GB)
        $PercentageFree = [math]::Round(($FreeSpace)/($Capacity)*100)
        $PercentFree = "{0:P0}" -f ($PercentageFree/100)
        $object | Add-Member -MemberType NoteProperty -Name "VM" -Value $vm.Name
        $object | Add-Member -MemberType NoteProperty -Name Disk -Value $_.DiskPath
        $object | Add-Member -MemberType NoteProperty -Name "TotalCapacity" -Value $Capacity
        $object | Add-Member -MemberType NoteProperty -Name "FreeSpace" -Value $FreeSpace
        $object | Add-Member -MemberType NoteProperty -Name "PercentFree" -Value $PercentFree
        $finalResult += $object
    }
    $object = New-Object -TypeName PSObject
    $object | Add-Member -MemberType NoteProperty -Name "VM" -Value $vm.Name
    $object | Add-Member -MemberType NoteProperty -Name Disk -Value 'SubTotal'
    $object | Add-Member -MemberType NoteProperty -Name "TotalCapacity" -Value ("{0:N0}" -f ($totalCapacity/1GB))
    $object | Add-Member -MemberType NoteProperty -Name "FreeSpace" -Value ("{0:N0}" -f ($totalFree/1GB))
    $object | Add-Member -MemberType NoteProperty -Name "PercentFree" -Value ("{0:P0}" -f ($totalFree/$totalCapacity))
    $finalResult += $object
}
$finalResult | Export-Csv .\DiskUsageReport.csv -NoTypeInformation -UseCulture
