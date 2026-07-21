function Clear-VMHostSEL {
    Param(
      [parameter(Mandatory=$true, ValueFromPipeline=$true)]$VMHosts
    )
    process {
      foreach($VMHost in $VMHosts){
        $VMhostView = Get-View $VMHost
        Write-Host "Clearing System Event Log Of: $VMHost"
        $VMhostHealthView = Get-View -Id $VMhostView.ConfigManager.HealthStatusSystem
        $VMhostHealthView.ClearSystemEventLog()
      }
    }
} # End Function Clear-VMHostSEL
Get-VMhost -Name SomeHost | Clear-VMHostSEL