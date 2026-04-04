Get-Cluster -Location $BostonDC -Name "Production" | Set-Cluster -HAEnabled $true -HAAdmissionControlEnabled $true -HAFailoverLevel 1 -HARestartPriority "Medium"
