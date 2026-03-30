# Get-WmiObject was deprecated in PowerShell 6 and removed in PowerShell 7+.
# Use Get-CimInstance instead.
# Update $HotfixIDs below with the KB numbers relevant to your environment.

$HotfixIDs = @(
    "KB5040442",
    "KB5039894"
    # Add additional KB IDs as needed
)

$script = @"
  `$hotfix = @('$($HotfixIDs -join "','")')
  `$fixes  = Get-CimInstance -ClassName Win32_QuickFixEngineering |
             Where-Object { `$hotfix -contains `$_.HotFixID } |
             Select-Object -ExpandProperty HotFixID
  if (`$fixes) { "`$(`$fixes -join ',') installed" }
  else         { "No matching hotfixes found" }
"@

# Prompt for guest credentials — supports a single credential set.
# If your environment has VMs with different local admin passwords, call
# Get-Credential multiple times and build the $accounts array accordingly.
$cred = Get-Credential -Message "Enter guest VM Administrator credentials"
$accounts = @(
    @{ User = $cred.UserName; Pswd = $cred.GetNetworkCredential().Password }
)

Get-ResourcePool -Name 'testpool' -PipelineVariable rp | ForEach-Object {
    Get-VM -Location $rp -PipelineVariable vm | ForEach-Object {
        $out = 'Login failed'
        foreach ($account in $accounts) {
            try {
                $sInvoke = @{
                    VM            = $vm
                    GuestUser     = $account.User
                    GuestPassword = $account.Pswd
                    ScriptText    = $script
                    ScriptType    = 'Powershell'
                    ErrorAction   = 'Stop'
                }
                $out = Invoke-VMScript @sInvoke | Select-Object -ExpandProperty ScriptOutput
                break
            } catch {}
        }
        [PSCustomObject][ordered]@{
            Name   = $vm.Name
            OS     = $vm.Guest.OSFullName
            IP     = $vm.Guest.IPAddress -join '|'
            RP     = $rp.Name
            Result = $out
        }
    }
} | Export-Csv -Path .\Output.csv -NoTypeInformation -NoClobber
