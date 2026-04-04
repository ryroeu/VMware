#################### Variables ####################
$VMs = 'NameofVM'
$VHD = 'Hard disk 1'
$IncreaseSpace = 20
#################### Extend ####################
foreach ($VM in $VMs){
    $SizeVHD = Get-HardDisk -Name $VHD -VM $VM | Select-Object -ExpandProperty CapacityGB
    Get-HardDisk -Name $VHD -VM $VM | Set-HardDisk -CapacityGB ($SizeVHD + $IncreaseSpace) -Confirm:$false
    Update-HostStorageCache
    $SizePart = (Get-PartitionSupportedSize -DriveLetter C)
    Resize-Partition -DriveLetter C -Size $SizePart.SizeMax -Confirm:$false
}
