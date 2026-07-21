$AllClusters = @()
Get-Cluster * | ForEach-Object {
    $clusstat = "" | Select-Object ClusterName, MemMax, MemAvg, MemMin, CPUMax, CPUAvg, CPUMin
    $clusstat.ClusterName = $_.Name
    $statcpu = Get-Stat -Entity $_ -Start (get-date).AddDays(-30) -Finish (Get-Date)-MaxSamples 1000 -Stat cpu.usage.average
    $statmem = Get-Stat -Entity $_ -Start (get-date).AddDays(-30) -Finish (Get-Date)-MaxSamples 1000 -Stat mem.usage.average
    $cpu = $statcpu | Measure-Object -Property Value -Average -Maximum -Minimum
    $mem = $statmem | Measure-Object -Property Value -Average -Maximum -Minimum
    $clusstat.CPUMax = [math]::Round($cpu.Maximum)
    $clusstat.CPUAvg = [math]::Round($cpu.Average)
    $clusstat.CPUMin = [math]::Round($cpu.Minimum)
    $clusstat.MemMax = [math]::Round($mem.Maximum)
    $clusstat.MemAvg = [math]::Round($mem.Average)
    $clusstat.MemMin = [math]::Round($mem.Minimum)
    $AllClusters += $clusstat
}
$AllClusters | Select-Object ClusterName, MemMax, MemAvg, MemMin, CPUMax, CPUAvg, CPUMin | Export-Csv .\CPURAMPerfClusters.csv -NoTypeInformation
