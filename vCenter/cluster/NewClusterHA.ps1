New-Cluster -Location $BostonDC -Name "Production" -HAEnabled -HAAdmissionControlEnabled -HAFailoverLevel 1 -HARestartPriority "Medium"
