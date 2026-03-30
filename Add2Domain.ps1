$DomainName  = "domain.com"
$GuestCred   = Get-Credential -Message "Enter local Administrator credentials for the guest VMs"
$DomainCred  = Get-Credential -Message "Enter domain join credentials for $DomainName"

# Invoke-VMScript runs the script inside the guest, so domain credentials must be
# embedded in the script text — Get-Credential above avoids hardcoding them in the file.
$DomainUser  = $DomainCred.UserName
$DomainPass  = $DomainCred.GetNetworkCredential().Password

$JoinNewDomain = @"
`$DomainUser = '$DomainUser'
`$DomainPWord = ConvertTo-SecureString -String '$DomainPass' -AsPlainText -Force
`$DomainCredential = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList `$DomainUser, `$DomainPWord
Add-Computer -DomainName '$DomainName' -Credential `$DomainCredential
Start-Sleep -Seconds 20
Shutdown /r /t 0
"@

$vmList = Import-Csv .\ServerNames.csv -Header OldName, NewName
foreach ($vmName in $vmList) {
    Invoke-VMScript -VM $vmName.OldName -ScriptType PowerShell -ScriptText $JoinNewDomain -GuestCredential $GuestCred
}
