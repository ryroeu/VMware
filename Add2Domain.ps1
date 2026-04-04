$DomainName = "domain.com"
$GuestCred = Get-Credential -Message "Enter local Administrator credentials for the guest VMs"
$DomainCred = Get-Credential -Message "Enter domain join credentials for $DomainName"

function ConvertTo-EncodedGuestPowerShellCommand {
    param(
        [Parameter(Mandatory=$true)]
        [string]$ScriptText
    )

    [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($ScriptText))
}

# Invoke-VMScript runs the script inside the guest, so domain credentials must be
# embedded in the script text. Launch Windows PowerShell explicitly so the guest
# script doesn't depend on pwsh shipping in the VM.
$DomainUser = $DomainCred.UserName
$DomainPass = $DomainCred.GetNetworkCredential().Password
$EscapedDomainUser = $DomainUser.Replace("'", "''")
$EscapedDomainPass = $DomainPass.Replace("'", "''")
$EscapedDomainName = $DomainName.Replace("'", "''")

$JoinNewDomain = @"
`$DomainUser = '$EscapedDomainUser'
`$DomainPWord = ConvertTo-SecureString -String '$EscapedDomainPass' -AsPlainText -Force
`$DomainCredential = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList `$DomainUser, `$DomainPWord
Add-Computer -DomainName '$EscapedDomainName' -Credential `$DomainCredential
Restart-Computer -Force
"@

$encodedCommand = ConvertTo-EncodedGuestPowerShellCommand -ScriptText $JoinNewDomain
$guestCommand = "%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass -EncodedCommand $encodedCommand"

$vmList = Import-Csv .\ServerNames.csv -Header OldName, NewName
foreach ($vmName in $vmList) {
    Invoke-VMScript -VM $vmName.OldName -ScriptType Bat -ScriptText $guestCommand -GuestCredential $GuestCred
}
