### CONNECT TO VCENTER ###
$vCenterServer = "10.10.10.10"
$vCenterCred   = Get-Credential -Message "Enter vCenter credentials"
Connect-VIServer -Server $vCenterServer -Protocol https -Credential $vCenterCred