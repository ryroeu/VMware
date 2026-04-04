$CDT = Get-Date
$Start = (Get-Date).AddDays(-7)
Get-VM | Get-VIEvent -Types Info -Start $Start -Finish $CDT | Where-Object {$_ -is [Vmware.vim.VmBeingDeployedEvent] -or $_ -is [Vmware.vim.VmCreatedEvent] -or $_ -is [Vmware.vim.VmRegisteredEvent]} | Select-Object UserName, CreatedTime, FullFormattedMessage | Export-Csv .\DeployedVMs.csv -NoTypeInformation
