Get-Cluster -Location $BostonDC -Name "Production" | Set-Cluster -DrsEnabled $true -DrsAutomationLevel "FullyAutomated" -Confirm:$false
