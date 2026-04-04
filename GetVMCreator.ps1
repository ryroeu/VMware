$report = @()
$cnt = 1
Measure-Command {
    $view = Get-View -ViewType Virtualmachine -Property Name,Config,Guest
    Write-Host "Found $($view.count) virtual machines"
    $events = Get-VIEvent -Entity $view.Name -MaxSamples ([int]::MaxValue) |
        Where-Object { $_ -is [VMware.Vim.VmDeployedEvent] -or
                       $_ -is [VMware.Vim.VmClonedEvent]-or
                       $_ -is [VMware.Vim.VmCreatedEvent]-or
                       $_ -is [VMware.Vim.VmRegisteredEvent]}

    foreach ($vm in $view ) {
        if (!$vm.Config) { continue }
        Write-Host "Processing $($cnt) - $($vm.Name)"
        $vms = [PSCustomObject]@{
            VMName      = $vm.Name
            Hostname    = $vm.guest.hostname
            OS          = $vm.Config.GuestFullName
            IPAddress   = $vm.guest.ipAddress
            CreatedDate = $vm.Config.CreateDate
            Creator     = ($events | Where-Object {$_.VM.Name -eq $vm.Name} | Sort-Object -Property CreatedTime -Descending | Select-Object -First 1).UserName
            Notes       = $vm.Config.Annotation -replace '(?:\r|\n)', ''
        }
        $report += $vms
        $cnt++
    }
}
$report