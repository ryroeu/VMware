# Get-VMGuestPartition was removed from PowerCLI.
# Use the View API (Guest.Disk) instead — requires VMware Tools running in the guest.

#### Get partitions in Guest OS ####

# All partitions for all powered-on VMs:
#Get-VM -Name * | Where-Object {$_.PowerState -eq "PoweredOn"} | ForEach-Object {
#    $vm = $_
#    ($vm | Get-View).Guest.Disk | ForEach-Object {
#        [PSCustomObject]@{
#            VM          = $vm.Name
#            Volume      = $_.DiskPath
#            FreeSpaceMB = [math]::Round($_.FreeSpace / 1MB)
#            'Usage%'    = [math]::Round((($_.Capacity - $_.FreeSpace) / $_.Capacity) * 100, 1)
#        }
#    }
#} | Where-Object {$_.FreeSpaceMB -lt 1000} | Format-Table -AutoSize

# C: drive partitions over 85% used — exported to CSV:
Get-VM -Name * | Where-Object {$_.PowerState -eq "PoweredOn"} | ForEach-Object {
    $vm = $_
    ($vm | Get-View).Guest.Disk | Where-Object {$_.DiskPath -eq 'C:\'} | ForEach-Object {
        if ($_.Capacity -gt 0) {
            [PSCustomObject]@{
                VM          = $vm.Name
                Volume      = $_.DiskPath
                FreeSpaceMB = [math]::Round($_.FreeSpace / 1MB)
                'Usage%'    = [math]::Round((($_.Capacity - $_.FreeSpace) / $_.Capacity) * 100, 1)
            }
        }
    }
} | Where-Object {$_.'Usage%' -gt 85} | Export-Csv .\Partitions85Percent.csv -NoTypeInformation
