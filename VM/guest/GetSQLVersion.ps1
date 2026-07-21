$VMs       = Import-Csv -Path .\VMs.csv
$GuestCred = Get-Credential -Message "Enter guest VM credentials"

$Script = @'
Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*",
                 "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*" |
    Where-Object { $_.DisplayName -like "Microsoft SQL Server*" } |
    Select-Object DisplayName, DisplayVersion |
    Sort-Object DisplayName
'@

foreach ($VM in $VMs) {
    Invoke-VMScript -ScriptText $Script -VM $VM.Name -GuestCredential $GuestCred -ScriptType Powershell |
        Select-Object @{N='VM'; E={$VM.Name}}, ScriptOutput |
        Out-File .\SQLVersions.txt -Append
}
