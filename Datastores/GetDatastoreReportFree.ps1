# Get-VmfsDatastoreInfo and Get-VmfsDatastoreIncrease were removed from PowerCLI.
# Use Get-Datastore and the View API instead.

$DatastoreName = "VMHostingDataStore-01"

# Capacity and free space report
Get-Datastore -Name $DatastoreName | Select-Object Name,
    @{N='CapacityGB';   E={[math]::Round($_.CapacityGB, 2)}},
    @{N='FreeSpaceGB';  E={[math]::Round($_.FreeSpaceGB, 2)}},
    @{N='UsedGB';       E={[math]::Round($_.CapacityGB - $_.FreeSpaceGB, 2)}},
    @{N='FreePercent';  E={[math]::Round($_.FreeSpaceGB / $_.CapacityGB * 100, 1)}} |
    Export-Csv .\DataStoreReport.csv -NoTypeInformation

# VMFS extent information (replaces Get-VmfsDatastoreIncrease)
Get-Datastore -Name $DatastoreName | Get-View | ForEach-Object {
    if ($_.Info -is [VMware.Vim.VmfsDatastoreInfo]) {
        $dsName = $_.Info.Vmfs.Name
        $_.Info.Vmfs.Extent | ForEach-Object {
            [PSCustomObject]@{
                Datastore  = $dsName
                DiskName   = $_.DiskName
                Partition  = $_.Partition
                StartBlock = $_.StartBlock
                EndBlock   = $_.EndBlock
            }
        }
    }
} | Export-Csv .\DataStoreExpandReport.csv -NoTypeInformation
