###############VARIABLES###############
#Original IP to replace"
$origIp = "10.67.133.223"
#New IP Information
$newIp = "10.10.10.10"
$newMask = "255.255.255.0"
$newGateway = "10.10.10.1"
$newDNS = "10.10.10.9"
#Guest Credentials - Must have required permissions to change IP address
$GuestCred = Get-Credential -Message "Enter guest VM credentials (must have permission to change IP)"
#VM Inventory names to match
$matchVMs = "NameofVM"
##############NO CHANGES BEYOND THIS POINT##############
#List of VMs (vCenter Inventory Names) to change
Write-Host "Getting list of VMs from Inventory where Inventory Name contains $matchVMs"
$VMs = (get-vm | Where-Object {$_.Name -match $matchVMs -and $_.PowerState -eq "PoweredOn"}).Name
foreach ($vm in $VMs){
   Write-Host "Working on $vm"
   #PowerShell used by Invoke-VMScript to retrieve current IP Address
   $ipscript = '(Get-NetIPAddress | where-object {$_.IPAddress -match "' + $origIp + '" -and $_.AddressFamily -eq "IPv4"}).IPAddress'
   $currentIp = invoke-vmscript -ScriptText $ipscript -ScriptType PowerShell -VM $vm -GuestCredential $GuestCred
   $currentIp = $currentIp -replace "`t|`n|`r",""
   write-host "$currentIp is the current IP Address"
   #Adjust Original IP to Replacement IP
   $changeIp = $currentIp.replace("$origIp", "$newIp")
   $changeIp = $changeIp -replace "`t|`n|`r",""
   Write-Host "Changing IP to $changeIp"
   #Get the Interface Name (Alias)
   $aliasscript = '(Get-NetIPAddress | where-object {$_.IPAddress -match "' + $origIp + '" -and $_.AddressFamily -eq "IPv4"}).InterfaceAlias'
   $getIntAlias = invoke-vmscript -ScriptText $aliasscript -ScriptType PowerShell -VM $vm -GuestCredential $GuestCred
   $getIntAlias = $getIntAlias -replace "`t|`n|`r",""
   write-host "The interface name is $getIntAlias"
   #Change the IP Address
   $changingIp = '%WINDIR%\system32\netsh.exe interface ipv4 set address name="' + $getIntAlias + '" source=static address=' + $changeIp + ' mask=' + $newMask + ' gateway=' + $newGateway + ' gwmetric=1 store=persistent'
   Write-host "Changing IP Address of $vm interface $getIntAlias from $currentIp to $changeIp"
   Invoke-VMScript -ScriptText $changingIp -ScriptType bat -VM $vm -GuestCredential $GuestCred
   #Change DNS Servers
   Write-Host "Setting DNS Server to $newDNS"
   $changeDNS = '%WINDIR%\system32\netsh.exe interface ipv4 set dnsservers name="' + $getIntAlias + '" source=static address=' + $newDNS + ' register=primary'
   Invoke-VMScript -ScriptText $changeDNS -ScriptType bat -VM $vm -GuestCredential $GuestCred
   #Register with DNS
   Write-Host "Registering with DNS"
   $registeringDNS = '%WINDIR%\System32\ipconfig /registerdns'
   Invoke-VMScript -ScriptText $registeringDNS -ScriptType bat -VM $vm -GuestCredential $GuestCred
   Write-Host "Finished with $vm"
}
