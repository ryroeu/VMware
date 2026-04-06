Get-VM -Name * | Get-Snapshot | Where-Object {$_.Created -lt (Get-Date).AddDays(-30)} | Remove-Snapshot -Confirm:$false
