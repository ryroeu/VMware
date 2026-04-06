Get-VM -Name * | Get-Snapshot | Where-Object {$_.Created -lt (Get-Date).AddDays(-30)} | Select-Object VM, Name, Created | Export-Csv .\Snapshots30Days.csv -NoTypeInformation
