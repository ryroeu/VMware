$AllVMs = @()
Get-VM * | ForEach-Object {
    $vmstat = “” | Select-Object VmName, CPUMin, CPUAvg, CPUMax, MemMin, MemAvg, MemMax
    $vmstat.VmName = $_.name
    $statcpu = Get-Stat -Entity $_ -start (get-date).AddDays(-30) -Finish (Get-Date) -MaxSamples 1000 -stat cpu.usage.average
    $statmem = Get-Stat -Entity $_ -start (get-date).AddDays(-30) -Finish (Get-Date) -MaxSamples 1000 -stat mem.usage.average
    $cpu = $statcpu | Measure-Object -Property value -Average -Maximum -Minimum
    $mem = $statmem | Measure-Object -Property value -Average -Maximum -Minimum
    $vmstat.CPUMax = [math]::Round($cpu.Maximum)
    $vmstat.CPUAvg = [math]::Round($cpu.Average)
    $vmstat.CPUMin = [math]::Round($cpu.Minimum)
    $vmstat.MemMax = [math]::Round($mem.Maximum)
    $vmstat.MemAvg = [math]::Round($mem.Average)
    $vmstat.MemMin = [math]::Round($mem.Minimum)
    $AllVMs += $vmstat
}
$AllVMs | Select-Object VmName, CPUMin, CPUAvg, CPUMax, MemMin, MemAvg, MemMax | Export-Csv .\CPURAMPerfVMs.csv -NoTypeInformation
