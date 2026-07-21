$AllHosts = @()
Get-VMHost * | ForEach-Object {
    $hoststat = "" | Select-Object HostName, MemMax, MemAvg, MemMin, CPUMax, CPUAvg, CPUMin
    $hoststat.HostName = $_.Name
    $statcpu = Get-Stat -Entity $_ -Start (Get-Date).AddDays(-30) -Finish (Get-Date)-MaxSamples 1000 -Stat cpu.usage.average
    $statmem = Get-Stat -Entity $_ -Start (Get-Date).AddDays(-30) -Finish (Get-Date)-MaxSamples 1000 -Stat mem.usage.average
    $cpu = $statcpu | Measure-Object -Property value -Average -Maximum -Minimum
    $mem = $statmem | Measure-Object -Property value -Average -Maximum -Minimum
    $hoststat.CPUMax = [math]::Round($cpu.Maximum)
    $hoststat.CPUAvg = [math]::Round($cpu.Average)
    $hoststat.CPUMin = [math]::Round($cpu.Minimum)
    $hoststat.MemMax = [math]::Round($mem.Maximum)
    $hoststat.MemAvg = [math]::Round($mem.Average)
    $hoststat.MemMin = [math]::Round($mem.Minimum)
    $AllHosts += $hoststat
}
$AllHosts | Select-Object HostName, MemMax, MemAvg, MemMin, CPUMax, CPUAvg, CPUMin | Export-Csv .\CPURAMPerfHosts.csv -NoTypeInformation
