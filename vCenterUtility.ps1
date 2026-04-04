<# DOMAIN MIGRATION UTILITY - VERSION 1.4 #>
using namespace System.Management.Automation.Host

<# GENERAL VARIABLES #>
$VMListPath = Join-Path -Path $PSScriptRoot -ChildPath 'VMList.txt'
$VMs = Get-Content -Path $VMListPath
$Domain = 'domain.com'
$DC = 'COMPUTERNAME'
$DCIP = '10.10.10.30'
$PrimaryDnsServer = '10.10.10.1'
$SecondaryDnsServer = '10.10.10.2'
$ServiceAccountMatch = 'svc startname'
$PingDomain = "ping $Domain"
$PingDC = "ping $DC.$Domain"
$PingDCIP = "ping $DCIP"
$UsersInGroup = @'
if (Get-Command -Name Get-LocalGroupMember -ErrorAction SilentlyContinue) {
    Get-LocalGroupMember -Group 'Administrators' |
        Select-Object Name, ObjectClass, PrincipalSource |
        Sort-Object Name |
        Format-Table -AutoSize | Out-String
}
else {
    ([ADSI]'WinNT://./Administrators,group').psbase.Invoke('Members') |
        ForEach-Object {
            [pscustomobject]@{
                Name = $_.GetType().InvokeMember('Name', 'GetProperty', $null, $_, $null)
                Path = $_.GetType().InvokeMember('AdsPath', 'GetProperty', $null, $_, $null)
            }
        } |
        Sort-Object Name |
        Format-Table -AutoSize | Out-String
}
'@
$Add2GroupCD = $null
$GetDomainOnVM = @'
if (Get-Command -Name Get-CimInstance -ErrorAction SilentlyContinue) {
    (Get-CimInstance -ClassName Win32_ComputerSystem).Domain
}
else {
    (Get-WmiObject -Class Win32_ComputerSystem).Domain
}
'@
$GetDNSAddress = @'
if (Get-Command -Name Get-DnsClientServerAddress -ErrorAction SilentlyContinue) {
    Get-DnsClientServerAddress -AddressFamily IPv4 |
        Where-Object { $_.ServerAddresses } |
        Select-Object InterfaceAlias, @{ Name = 'ServerAddresses'; Expression = { $_.ServerAddresses -join ', ' } } |
        Format-Table -AutoSize | Out-String
}
else {
    Get-WmiObject -Class Win32_NetworkAdapterConfiguration |
        Where-Object { $_.IPEnabled -and $_.DNSServerSearchOrder } |
        Select-Object Description, @{ Name = 'ServerAddresses'; Expression = { $_.DNSServerSearchOrder -join ', ' } } |
        Format-Table -AutoSize | Out-String
}
'@
$SetDNSAddress = @"
`$dnsServers = @('$PrimaryDnsServer', '$SecondaryDnsServer')
if (Get-Command -Name Set-DnsClientServerAddress -ErrorAction SilentlyContinue) {
    `$adapterIndexes = Get-DnsClientServerAddress -AddressFamily IPv4 |
        Where-Object { `$_.InterfaceAlias -notmatch 'Loopback|isatap|Teredo' } |
        Select-Object -ExpandProperty InterfaceIndex -Unique
    if (-not `$adapterIndexes) {
        throw 'No compatible IPv4 adapters were found.'
    }
    foreach (`$adapterIndex in `$adapterIndexes) {
        Set-DnsClientServerAddress -InterfaceIndex `$adapterIndex -ServerAddresses `$dnsServers -ErrorAction Stop
    }
    Get-DnsClientServerAddress -AddressFamily IPv4 |
        Where-Object { `$_.InterfaceIndex -in `$adapterIndexes } |
        Select-Object InterfaceAlias, @{ Name = 'ServerAddresses'; Expression = { `$_.ServerAddresses -join ', ' } } |
        Format-Table -AutoSize | Out-String
}
else {
    `$adapters = Get-WmiObject -Class Win32_NetworkAdapterConfiguration | Where-Object { `$_.IPEnabled }
    if (-not `$adapters) {
        throw 'No IP-enabled adapters were found.'
    }
    foreach (`$adapter in `$adapters) {
        `$result = `$adapter.SetDNSServerSearchOrder(`$dnsServers)
        if (`$result.ReturnValue -notin 0, 1) {
            throw \"SetDNSServerSearchOrder failed with code `$(`$result.ReturnValue).\"
        }
    }
    `$adapters |
        Select-Object Description, @{ Name = 'ServerAddresses'; Expression = { `$_.DNSServerSearchOrder -join ', ' } } |
        Format-Table -AutoSize | Out-String
}
"@
$RegisterDNS = @'
if (Get-Command -Name Register-DnsClient -ErrorAction SilentlyContinue) {
    Register-DnsClient | Out-Null
    'DNS registration initiated.'
}
else {
    ipconfig /registerdns | Out-String
}
'@
$GetSvcOnVM = @'
$services = if (Get-Command -Name Get-CimInstance -ErrorAction SilentlyContinue) {
    Get-CimInstance -ClassName Win32_Service
}
else {
    Get-WmiObject -Class Win32_Service
}
$services |
    Sort-Object Name |
    Select-Object Name, StartName |
    Format-Table -AutoSize | Out-String
'@
$GetDomainSvc = @"
`$serviceAccountMatch = '$ServiceAccountMatch'
`$services = if (Get-Command -Name Get-CimInstance -ErrorAction SilentlyContinue) {
    Get-CimInstance -ClassName Win32_Service
}
else {
    Get-WmiObject -Class Win32_Service
}
`$services |
    Where-Object { `$_.StartName -and `$_.StartName -match [regex]::Escape(`$serviceAccountMatch) } |
    Sort-Object StartName |
    Select-Object Name, StartName |
    Format-Table -AutoSize | Out-String
"@
$FWStatus = @'
if (Get-Command -Name Get-NetFirewallProfile -ErrorAction SilentlyContinue) {
    Get-NetFirewallProfile |
        Select-Object Name, Enabled, DefaultInboundAction, DefaultOutboundAction |
        Format-Table -AutoSize | Out-String
}
else {
    netsh advfirewall show allprofiles state | Out-String
}
'@
$FWDisable = @'
if (Get-Command -Name Set-NetFirewallProfile -ErrorAction SilentlyContinue) {
    Set-NetFirewallProfile -Profile Domain,Public,Private -Enabled False
    Get-NetFirewallProfile |
        Select-Object Name, Enabled |
        Format-Table -AutoSize | Out-String
}
else {
    netsh advfirewall set allprofiles state off | Out-String
}
'@
$TestADMTPortsScript = @"
function Test-GuestTcpPort {
    param(
        [Parameter(Mandatory)][string]`$ComputerName,
        [Parameter(Mandatory)][int]`$Port,
        [int]`$TimeoutMilliseconds = 2000
    )

    `$client = [System.Net.Sockets.TcpClient]::new()
    try {
        `$async = `$client.BeginConnect(`$ComputerName, `$Port, `$null, `$null)
        if (-not `$async.AsyncWaitHandle.WaitOne(`$TimeoutMilliseconds, `$false)) {
            return `$false
        }

        `$client.EndConnect(`$async)
        return `$true
    }
    catch {
        return `$false
    }
    finally {
        `$client.Dispose()
    }
}

`$target = '$DCIP'
[ordered]@{
    DNS      = 53
    Kerberos = 88
    RPC      = 135
    LDAP     = 389
    SMB      = 445
    GC       = 3268
}.GetEnumerator() |
    ForEach-Object {
        [pscustomobject]@{
            Target   = `$target
            PortName = `$_.Key
            Port     = `$_.Value
            Open     = Test-GuestTcpPort -ComputerName `$target -Port `$_.Value
        }
    } |
    Format-Table -AutoSize | Out-String
"@
# $ManualMoveScript is built after ADMT credentials are collected below


<# DOMAIN LOGIN VARIABLES #>
Write-Host "Let's get started! Please enter your Domain credentials." -ForegroundColor Magenta -BackgroundColor Black
$GuestUser = Read-Host "Enter your Domain UserName (Domain\UserName): "
$GuestPasswordSec = Read-Host "Enter your Domain Password: " -AsSecureString
$GuestCreds = New-Object System.Management.Automation.PSCredential ($GuestUser, $GuestPasswordSec)
<# ADMT LOGIN VARIABLES #>
Write-Host "Now let's get your ADMT credentials." -ForegroundColor Magenta -BackgroundColor Black
$ADMTAccount = Read-Host "Enter your ADMT account UserName (Domain\UserName): "
$ADMTPasswordSec = Read-Host "Enter your ADMT account Password: " -AsSecureString
$ADMTCreds = New-Object System.Management.Automation.PSCredential ($ADMTAccount, $ADMTPasswordSec)
$Add2GroupCD = @"
`$memberName = '$ADMTAccount'
if (Get-Command -Name Add-LocalGroupMember -ErrorAction SilentlyContinue) {
    `$memberExists = Get-LocalGroupMember -Group 'Administrators' -ErrorAction SilentlyContinue |
        Where-Object { `$_.Name -eq `$memberName }
    if (-not `$memberExists) {
        Add-LocalGroupMember -Group 'Administrators' -Member `$memberName -ErrorAction Stop
    }
}
else {
    net localgroup Administrators "`$memberName" /add | Out-Null
}
"`$memberName is a member of the local Administrators group."
"@
$ManualMoveScript = @"
`$DomainUser = '$ADMTAccount'
`$DomainPWord = ConvertTo-SecureString -String '$($ADMTCreds.GetNetworkCredential().Password)' -AsPlainText -Force
`$DomainCredential = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList `$DomainUser, `$DomainPWord
Add-Computer -DomainName '$Domain' -Credential `$DomainCredential
Start-Sleep -Seconds 20
Shutdown /r /t 0
"@
<# VCENTER LOGIN VARIABLES #>
Write-Host "Last step! Enter your vCenter password." -ForegroundColor Magenta -BackgroundColor Black
$vCenter = "10.10.10.20"
$vCenterUser = Read-Host "Enter your vCenter UserName (Domain\UserName): "
$vCenterPasswordSec = Read-Host "Enter your vCenter Password: " -AsSecureString
$vCenterCreds = New-Object System.Management.Automation.PSCredential ($vCenterUser, $vCenterPasswordSec)


<# FUNCTIONS #>
function Show-Menu {
    param (
        [string]$Title = 'Domain Migration Utility v1.4'
    )
    Clear-Host
    Write-Host "================ $Title ================"

    Write-Host "VCENTER AND VM LIST" -ForegroundColor DarkYellow -BackgroundColor Black
    Write-Host "1: Press '1' to connect to vCenter." -ForegroundColor DarkGreen -BackgroundColor Black
    Write-Host "2: Press '2' to disconnect from vCenter." -ForegroundColor DarkGreen -BackgroundColor Black
    Write-Host "3: Press '3' to show VMs in list." -ForegroundColor DarkGreen -BackgroundColor Black
    Write-Host "4: Press '4' to see if VMs are in vCenter." -ForegroundColor DarkGreen -BackgroundColor Black

    Write-Host "VMWARE TOOLS STATUS" -ForegroundColor DarkYellow -BackgroundColor Black
    Write-Host "91a: Press '91a' to check VMware Tools on specific VM." -ForegroundColor Blue -BackgroundColor Black
    Write-Host "91b: Press '91b' to check VMware Tools on each VM." -ForegroundColor DarkGreen -BackgroundColor Black
    Write-Host "92a: Press '92a' to update VMware Tools on specific VM." -ForegroundColor Blue -BackgroundColor Black
    Write-Host "92b: Press '92b' to update VMware Tools on each VM." -ForegroundColor DarkGreen -BackgroundColor Black

    Write-Host "VM POWER AND REBOOT" -ForegroundColor DarkYellow -BackgroundColor Black
    Write-Host "101a: Press '101a' to check Power Status on specific VM." -ForegroundColor Blue -BackgroundColor Black
    Write-Host "101b: Press '101b' to check Power Status on each VM." -ForegroundColor DarkGreen -BackgroundColor Black
    Write-Host "102a: Press '102a' to reboot a specific VM." -ForegroundColor Blue -BackgroundColor Black
    Write-Host "103a: Press '103a' to power on a specific VM." -ForegroundColor Blue -BackgroundColor Black
    Write-Host "104a: Press '104a' to shutdown a specific VM." -ForegroundColor Blue -BackgroundColor Black
    Write-Host "105a: Press '105a' to power off a specific VM." -ForegroundColor Blue -BackgroundColor Black

    Write-Host "VM CPU AND MEMORY" -ForegroundColor DarkYellow -BackgroundColor Black
    Write-Host "121a: Press '121a' to get weekly CPU and Memory usage report on specific VM." -ForegroundColor Blue -BackgroundColor Black
    Write-Host "121b: Press '121b' to get weekly CPU and Memory usage report on each VM." -ForegroundColor DarkGreen -BackgroundColor Black
    Write-Host "122a: Press '122a' to get monthly CPU and Memory usage report on specific VM." -ForegroundColor Blue -BackgroundColor Black
    Write-Host "122b: Press '122b' to get monthly CPU and Memory usage report on each VM." -ForegroundColor DarkGreen -BackgroundColor Black

    Write-Host "WINDOWS ADMIN ACCOUNTS" -ForegroundColor DarkYellow -BackgroundColor Black
    Write-Host "11a: Press '11a' to show users in Admins group on specific VM." -ForegroundColor DarkGreen -BackgroundColor Black
    Write-Host "11b: Press '11b' to show users in Admins group on each VM." -ForegroundColor DarkGreen -BackgroundColor Black
    Write-Host "12a: Press '12a' to add ADMT account to Admins group on specific VM." -ForegroundColor Blue -BackgroundColor Black
    Write-Host "12b: Press '12b' to add ADMT account to Admins group on each VM." -ForegroundColor DarkGreen -BackgroundColor Black
    Write-Host "13a: Press '13a' to test authentication of ADMT account." -ForegroundColor Blue -BackgroundColor Black

    Write-Host "WINDOWS SERVICES" -ForegroundColor DarkYellow -BackgroundColor Black
    Write-Host "31a: Press '31a' to get all services on specific VM." -ForegroundColor Blue -BackgroundColor Black
    Write-Host "31b: Press '31b' to get all services on each VM." -ForegroundColor DarkGreen -BackgroundColor Black
    Write-Host "32a: Press '32a' to check for a specific Service on specific VM." -ForegroundColor Blue -BackgroundColor Black
    Write-Host "32b: Press '32b' to check for a specific Service on each VM." -ForegroundColor DarkGreen -BackgroundColor Black

    Write-Host "IP AND DNS ADDRESSES" -ForegroundColor DarkYellow -BackgroundColor Black
    Write-Host "21a: Press '21a' to get IP Address for specific VM." -ForegroundColor DarkGreen -BackgroundColor Black
    Write-Host "21b: Press '21b' to get IP Address for each VM." -ForegroundColor DarkGreen -BackgroundColor Black
    Write-Host "22a: Press '22a' to get the current Domain for specific VM." -ForegroundColor DarkGreen -BackgroundColor Black
    Write-Host "22b: Press '22b' to get the current Domain for each VM." -ForegroundColor DarkGreen -BackgroundColor Black
    Write-Host "23a: Press '23a' to get DNS Server Address on specific VM." -ForegroundColor DarkGreen -BackgroundColor Black
    Write-Host "23b: Press '23b' to get DNS Server Address for each VM." -ForegroundColor DarkGreen -BackgroundColor Black
    Write-Host "24a: Press '24a' to set the DNS Server Address on specific VM." -ForegroundColor Blue -BackgroundColor Black
    Write-Host "24b: Press '24b' to set the DNS Server Address on each VM." -ForegroundColor Blue -BackgroundColor Black
    Write-Host "25a: Press '25a' to register DNS on specific VM." -ForegroundColor DarkGreen -BackgroundColor Black
    Write-Host "25b: Press '25b' to register DNS on each VM." -ForegroundColor DarkGreen -BackgroundColor Black

    Write-Host "NETWORK CONNECTIVITY" -ForegroundColor DarkYellow -BackgroundColor Black
    Write-Host "41a: Press '41a' to ping ComputerName of specific VM." -ForegroundColor DarkGreen -BackgroundColor Black
    Write-Host "41b: Press '41b' to ping ComputerName of each VM." -ForegroundColor DarkGreen -BackgroundColor Black
    Write-Host "42a: Press '42a' to ping IP Address of specific VM." -ForegroundColor DarkGreen -BackgroundColor Black
    Write-Host "42b: Press '42b' to ping IP Address of each VM." -ForegroundColor DarkGreen -BackgroundColor Black
    Write-Host "43a: Press '43a' to ping the Admin share on specific VM." -ForegroundColor DarkGreen -BackgroundColor Black
    Write-Host "43b: Press '43b' to ping the Admin share on each VM." -ForegroundColor DarkGreen -BackgroundColor Black
    Write-Host "44a: Press '44a' to test reachability of DC from specific VM." -ForegroundColor DarkGreen -BackgroundColor Black
    Write-Host "44b: Press '44b' to test reachability of DC from each VM." -ForegroundColor DarkGreen -BackgroundColor Black
    Write-Host "44c: Press '44c' to test reachability of DC IP from each VM." -ForegroundColor DarkGreen -BackgroundColor Black
    Write-Host "48a: Press '48a' to check ADMT ports on specific VM." -ForegroundColor DarkGreen -BackgroundColor Black
    Write-Host "48b: Press '48b' to check ADMT ports on each VM." -ForegroundColor DarkGreen -BackgroundColor Black

    Write-Host "WINDOWS FIREWALL" -ForegroundColor DarkYellow -BackgroundColor Black
    Write-Host "51a: Press '51a' to get status of Windows Firewall on specific VM." -ForegroundColor DarkGreen -BackgroundColor Black
    Write-Host "51b: Press '51b' to get status of Windows Firewall on each VM." -ForegroundColor DarkGreen -BackgroundColor Black
    Write-Host "52a: Press '52a' to disable Windows Firewall on specific VM." -ForegroundColor Blue -BackgroundColor Black
    Write-Host "52b: Press '52b' to disable Windows Firewall on each VM." -ForegroundColor Blue -BackgroundColor Black

    Write-Host "BACKUP POLICY" -ForegroundColor DarkYellow -BackgroundColor Black
    Write-Host "61a: Press '61a' to check Backup Policy on specific VM is set to Exclude." -ForegroundColor DarkGreen -BackgroundColor Black
    Write-Host "61b: Press '61b' to check Backup Policy on each VM is set to Exclude." -ForegroundColor DarkGreen -BackgroundColor Black
    Write-Host "62a: Press '62a' to check Backup Policy on specific VM is set to Snapshot." -ForegroundColor DarkGreen -BackgroundColor Black
    Write-Host "62b: Press '62b' to check Backup Policy on each VM is set to Snapshot." -ForegroundColor DarkGreen -BackgroundColor Black
    Write-Host "64a: Press '64a' to set Backup Policy to Exclude on specific VM." -ForegroundColor Blue -BackgroundColor Black
    Write-Host "64b: Press '64b' to set Backup Policy to Exclude on each VM." -ForegroundColor Blue -BackgroundColor Black
    Write-Host "65a: Press '65a' to set Backup Policy to Snapshot on specific VM." -ForegroundColor Blue -BackgroundColor Black
    Write-Host "65b: Press '65b' to set Backup Policy to Snapshot on each VM." -ForegroundColor Blue -BackgroundColor Black

    Write-Host "MANUAL MOVES" -ForegroundColor DarkYellow -BackgroundColor Black
    Write-Host "81a: Press '81a' to manually move specific VM to new domain." -ForegroundColor Blue -BackgroundColor Black
    Write-Host "81b: Press '81b' to manually move each VM to new domain." -ForegroundColor Blue -BackgroundColor Black

    Write-Host "SNAPSHOTS" -ForegroundColor DarkYellow -BackgroundColor Black
    Write-Host "71a: Press '71a' to take Snapshot of specific VM." -ForegroundColor Blue -BackgroundColor Black
    Write-Host "71b: Press '71b' to take Snapshot of each VM." -ForegroundColor Blue -BackgroundColor Black
    Write-Host "72a: Press '72a' to remove all Snapshots of specific VM." -ForegroundColor Blue -BackgroundColor Black
    Write-Host "72b: Press '72b' to remove all Snapshots of each VM." -ForegroundColor Blue -BackgroundColor Black

    Write-Host "VMOTION" -ForegroundColor DarkYellow -BackgroundColor Black
    Write-Host "111a: Press '111a' to get 24-hours of VMotion events of specific VM." -ForegroundColor Blue -BackgroundColor Black
    Write-Host "111b: Press '111b' to get 24-hours of VMotion events of each VM." -ForegroundColor DarkGreen -BackgroundColor Black
    Write-Host "112a: Press '112a' to get 1-week of VMotion events of specific VM." -ForegroundColor Blue -BackgroundColor Black
    Write-Host "112b: Press '112b' to get 1-week of VMotion events of each VM." -ForegroundColor DarkGreen -BackgroundColor Black

    Write-Host "Q: Press 'Q' to quit."
}

<# VCENTER AND LIST VERIFICATION #>
function Connect-2vCenter {
    Connect-VIServer -Server $vCenter -Credential $vCenterCreds
}

function New-NetworkCredentialFromCredential {
    param (
        [Parameter(Mandatory)]
        [System.Management.Automation.PSCredential]$Credential
    )

    $plainTextPassword = $Credential.GetNetworkCredential().Password

    if ($Credential.UserName -match '^(?<Domain>[^\\]+)\\(?<User>.+)$') {
        return [System.Net.NetworkCredential]::new($Matches.User, $plainTextPassword, $Matches.Domain)
    }

    return [System.Net.NetworkCredential]::new($Credential.UserName, $plainTextPassword)
}

function Get-PrimaryIPv4Address {
    param (
        [Parameter(Mandatory)]
        [string]$VMName
    )

    $guestInfo = Get-VMGuest -VM $VMName -ErrorAction Stop
    $ipAddress = $guestInfo.IPAddress |
        Where-Object { $_ -match '^\d{1,3}(\.\d{1,3}){3}$' } |
        Select-Object -First 1

    if (-not $ipAddress) {
        throw "Unable to determine an IPv4 address for $VMName. Verify VMware Tools is running and the guest has an IPv4 address."
    }

    $ipAddress
}

function Test-TcpPort {
    param (
        [Parameter(Mandatory)]
        [string]$ComputerName,

        [Parameter(Mandatory)]
        [int]$Port,

        [int]$TimeoutMilliseconds = 2000
    )

    $client = [System.Net.Sockets.TcpClient]::new()

    try {
        $async = $client.BeginConnect($ComputerName, $Port, $null, $null)
        if (-not $async.AsyncWaitHandle.WaitOne($TimeoutMilliseconds, $false)) {
            return $false
        }

        $client.EndConnect($async)
        return $true
    }
    catch {
        return $false
    }
    finally {
        $client.Dispose()
    }
}

function Show-AdminShareStatus {
    param (
        [Parameter(Mandatory)]
        [string]$ComputerName
    )

    if ($env:OS -eq 'Windows_NT') {
        if (Test-Path "\\$ComputerName\Admin$") {
            Write-Host "Admin share is reachable on $ComputerName" -ForegroundColor DarkGreen -BackgroundColor Black
        }
        else {
            Write-Host "Admin share is not reachable on $ComputerName" -ForegroundColor Red -BackgroundColor Black
        }

        return
    }

    if (Test-TcpPort -ComputerName $ComputerName -Port 445) {
        Write-Host "TCP 445 is reachable on $ComputerName. Share-level validation requires a Windows host." -ForegroundColor DarkGreen -BackgroundColor Black
    }
    else {
        Write-Host "TCP 445 is not reachable on $ComputerName" -ForegroundColor Red -BackgroundColor Black
    }
}

function Get-LocationOfVM {
    if (VMware.VimAutomation.Core\Get-VM -Name $VM -ErrorAction SilentlyContinue) {
        Write-Host "$VM exists in vCenter" -ForegroundColor DarkGreen -BackgroundColor Black
    } else {
        Write-Host "$VM does not exist in vCenter" -ForegroundColor Red -BackgroundColor Black
    }
}

<# VM CPU AND MEMORY #>
function Get-WeeklyCPURAM4VM {
    $TargetVM = Read-Host -Prompt "Enter the name of the VM: "
    Write-Host "Getting CPU and Memory Weekly Usage Report for $TargetVM" -ForegroundColor Blue -BackgroundColor Black
    $AllVMs = @()
    (VMware.VimAutomation.Core\Get-VM $TargetVM) | ForEach-Object {
        $vmstat = '' | Select-Object VmName, CPUMin, CPUAvg, CPUMax, MemMin, MemAvg, MemMax
        $vmstat.VmName = "$TargetVM"
        $statcpuweek = Get-Stat -Entity ($TargetVM) -Start (Get-Date).AddDays(-7) -Finish (Get-Date) -MaxSamples 100 -Stat cpu.usage.average
        $statmemweek = Get-Stat -Entity ($TargetVM) -Start (Get-Date).AddDays(-7) -Finish (Get-Date) -MaxSamples 100 -Stat mem.usage.average
        $cpuweek = $statcpuweek | Measure-Object -Property Value -Average -Maximum -Minimum
        $memweek = $statmemweek | Measure-Object -Property Value -Average -Maximum -Minimum
        $vmstat.CPUMax = [math]::Round($cpuweek.Maximum)
        $vmstat.CPUAvg = [math]::Round($cpuweek.Average)
        $vmstat.CPUMin = [math]::Round($cpuweek.Minimum)
        $vmstat.MemMax = [math]::Round($memweek.Maximum)
        $vmstat.MemAvg = [math]::Round($memweek.Average)
        $vmstat.MemMin = [math]::Round($memweek.Minimum)
        $AllVMs += $vmstat
    }
    $AllVMs | Select-Object VmName, CPUMin, CPUAvg, CPUMax, MemMin, MemAvg, MemMax
}

function Get-WeeklyCPURAM4All {
    Write-Host "Getting CPU and Memory Weekly Usage Report for $VM" -ForegroundColor DarkGreen -BackgroundColor Black
    $AllVMs = @()
    (VMware.VimAutomation.Core\Get-VM $VM) | ForEach-Object {
        $vmstat = '' | Select-Object VmName, CPUMin, CPUAvg, CPUMax, MemMin, MemAvg, MemMax
        $vmstat.VmName = "$VM"
        $statcpuweek = Get-Stat -Entity ($VM) -Start (Get-Date).AddDays(-7) -Finish (Get-Date) -MaxSamples 100 -Stat cpu.usage.average
        $statmemweek = Get-Stat -Entity ($VM) -Start (Get-Date).AddDays(-7) -Finish (Get-Date) -MaxSamples 100 -Stat mem.usage.average
        $cpuweek = $statcpuweek | Measure-Object -Property Value -Average -Maximum -Minimum
        $memweek = $statmemweek | Measure-Object -Property Value -Average -Maximum -Minimum
        $vmstat.CPUMax = [math]::Round($cpuweek.Maximum)
        $vmstat.CPUAvg = [math]::Round($cpuweek.Average)
        $vmstat.CPUMin = [math]::Round($cpuweek.Minimum)
        $vmstat.MemMax = [math]::Round($memweek.Maximum)
        $vmstat.MemAvg = [math]::Round($memweek.Average)
        $vmstat.MemMin = [math]::Round($memweek.Minimum)
        $AllVMs += $vmstat
    }
    $AllVMs | Select-Object VmName, CPUMin, CPUAvg, CPUMax, MemMin, MemAvg, MemMax
}

function Get-MonthlyCPURAM4VM {
    $TargetVM = Read-Host -Prompt "Enter the name of the VM: "
    Write-Host "Getting CPU and Memory Monthly Usage Report for $TargetVM" -ForegroundColor Blue -BackgroundColor Black
    $AllVMs = @()
    (VMware.VimAutomation.Core\Get-VM $TargetVM) | ForEach-Object {
        $vmstat = '' | Select-Object VmName, CPUMin, CPUAvg, CPUMax, MemMin, MemAvg, MemMax
        $vmstat.VmName = "$TargetVM"
        $statcpumonth = Get-Stat -Entity ($TargetVM) -Start (Get-Date).AddDays(-30) -Finish (Get-Date) -MaxSamples 1000 -Stat cpu.usage.average
        $statmemmonth = Get-Stat -Entity ($TargetVM) -Start (Get-Date).AddDays(-30) -Finish (Get-Date) -MaxSamples 1000 -Stat mem.usage.average
        $cpumonth = $statcpumonth | Measure-Object -Property value -Average -Maximum -Minimum
        $memmonth = $statmemmonth | Measure-Object -Property value -Average -Maximum -Minimum
        $vmstat.CPUMax = [math]::Round($cpumonth.Maximum)
        $vmstat.CPUAvg = [math]::Round($cpumonth.Average)
        $vmstat.CPUMin = [math]::Round($cpumonth.Minimum)
        $vmstat.MemMax = [math]::Round($memmonth.Maximum)
        $vmstat.MemAvg = [math]::Round($memmonth.Average)
        $vmstat.MemMin = [math]::Round($memmonth.Minimum)
        $AllVMs += $vmstat
    }
    $AllVMs | Select-Object VmName, CPUMin, CPUAvg, CPUMax, MemMin, MemAvg, MemMax
}

function Get-MonthlyCPURAM4All {
    Write-Host "Getting CPU and Memory Monthly Usage Report for $VM" -ForegroundColor DarkGreen -BackgroundColor Black
    $AllVMs = @()
    (VMware.VimAutomation.Core\Get-VM $VM) | ForEach-Object {
        $vmstat = '' | Select-Object VmName, CPUMin, CPUAvg, CPUMax, MemMin, MemAvg, MemMax
        $vmstat.VmName = "$VM"
        $statcpumonth = Get-Stat -Entity ($VM) -Start (Get-Date).AddDays(-30) -Finish (Get-Date) -MaxSamples 1000 -Stat cpu.usage.average
        $statmemmonth = Get-Stat -Entity ($VM) -Start (Get-Date).AddDays(-30) -Finish (Get-Date) -MaxSamples 1000 -Stat mem.usage.average
        $cpumonth = $statcpumonth | Measure-Object -Property value -Average -Maximum -Minimum
        $memmonth = $statmemmonth | Measure-Object -Property value -Average -Maximum -Minimum
        $vmstat.CPUMax = [math]::Round($cpumonth.Maximum)
        $vmstat.CPUAvg = [math]::Round($cpumonth.Average)
        $vmstat.CPUMin = [math]::Round($cpumonth.Minimum)
        $vmstat.MemMax = [math]::Round($memmonth.Maximum)
        $vmstat.MemAvg = [math]::Round($memmonth.Average)
        $vmstat.MemMin = [math]::Round($memmonth.Minimum)
        $AllVMs += $vmstat
    }
    $AllVMs | Select-Object VmName, CPUMin, CPUAvg, CPUMax, MemMin, MemAvg, MemMax
}

<# WINDOWS ADMIN ACCOUNTS #>
function Get-UsersInAdminGroup {
    $TargetVM = Read-Host -Prompt "Enter the name of the VM: "
    Write-Host "Getting users in Administrators group on $TargetVM" -ForegroundColor DarkGreen -BackgroundColor Black
    $SO = Invoke-VMScript -VM ($TargetVM) -GuestCredential $GuestCreds -ScriptType Powershell -ScriptText $UsersInGroup
    $SO.ScriptOutput
}

function Get-UsersInAdminGroupAll {
    Write-Host "Getting users in Administrators group on $VM" -ForegroundColor DarkGreen -BackgroundColor Black
    $SO = Invoke-VMScript -VM ($VM) -GuestCredential $GuestCreds -ScriptType Powershell -ScriptText $UsersInGroup
    $SO.ScriptOutput
}

function Add-Account2Group {
    $TargetVM = Read-Host -Prompt "Enter the name of the VM: "
    Write-Host "Adding $ADMTAccount to Administrators group on $TargetVM" -ForegroundColor Blue -BackgroundColor Black
    $SO = Invoke-VMScript -VM ($TargetVM) -GuestCredential $GuestCreds -ScriptType Powershell -ScriptText $Add2GroupCD
    $SO.ScriptOutput
}

function Add-Account2GroupAll {
    Write-Host "Adding $ADMTAccount to Administrators group on $VM" -ForegroundColor Blue -BackgroundColor Black
    $SO = Invoke-VMScript -VM ($VM) -GuestCredential $GuestCreds -ScriptType Powershell -ScriptText $Add2GroupCD
    $SO.ScriptOutput
}

function Test-ADAuthentication {
    Write-Host "Testing ADMT authentication against $DCIP" -ForegroundColor DarkGreen -BackgroundColor Black

    $targetDirectoryServer = if ([string]::IsNullOrWhiteSpace($DCIP)) {
        "$DC.$Domain"
    }
    else {
        $DCIP
    }

    $ldapConnection = $null

    try {
        $directoryIdentifier = [System.DirectoryServices.Protocols.LdapDirectoryIdentifier]::new($targetDirectoryServer, 389, $false, $false)
        $ldapConnection = [System.DirectoryServices.Protocols.LdapConnection]::new($directoryIdentifier)
        $ldapConnection.AuthType = [System.DirectoryServices.Protocols.AuthType]::Negotiate
        $ldapConnection.SessionOptions.ProtocolVersion = 3
        $ldapConnection.Credential = New-NetworkCredentialFromCredential -Credential $ADMTCreds
        $ldapConnection.Bind()

        Write-Host "ADMT authentication succeeded." -ForegroundColor DarkGreen -BackgroundColor Black
        $true
    }
    catch {
        Write-Host "ADMT authentication failed: $($_.Exception.Message)" -ForegroundColor Red -BackgroundColor Black
        $false
    }
    finally {
        if ($null -ne $ldapConnection) {
            $ldapConnection.Dispose()
        }
    }
}

<# IP AND DNS ADDRESSES #>
function Get-IPAddress4VM {
    $TargetVM = Read-Host -Prompt "Enter the name of the VM: "
    Write-Host "Getting IP of $TargetVM" -ForegroundColor DarkGreen -BackgroundColor Black
    Get-PrimaryIPv4Address -VMName $TargetVM
}
function Get-IPAddress4VMAll {
    Write-Host "Getting IP of $VM" -ForegroundColor DarkGreen -BackgroundColor Black
    Get-PrimaryIPv4Address -VMName $VM
}

function Get-DomainOnVM {
    $TargetVM = Read-Host -Prompt "Enter the name of the VM: "
    Write-Host "Getting Domain of $TargetVM" -ForegroundColor DarkGreen -BackgroundColor Black
    $SO = Invoke-VMScript -VM ($TargetVM) -GuestCredential $GuestCreds -ScriptType Powershell -ScriptText $GetDomainOnVM
    $SO.ScriptOutput
}

function Get-DomainOnVMAll {
    Write-Host "Getting Domain of $VM" -ForegroundColor DarkGreen -BackgroundColor Black
    $SO = Invoke-VMScript -VM ($VM) -GuestCredential $GuestCreds -ScriptType Powershell -ScriptText $GetDomainOnVM
    $SO.ScriptOutput
}

function Get-DNSServerAddress {
    $TargetVM = Read-Host -Prompt "Enter the name of the VM: "
    Write-Host "Getting DNS Server Address on $TargetVM" -ForegroundColor DarkGreen -BackgroundColor Black
    $SO = Invoke-VMScript -VM ($TargetVM) -GuestCredential $GuestCreds -ScriptType Powershell -ScriptText $GetDNSAddress
    $SO.ScriptOutput
}

function Get-DNSServerAddressAll {
    Write-Host "Getting DNS Server Address on $VM" -ForegroundColor DarkGreen -BackgroundColor Black
    $SO = Invoke-VMScript -VM ($VM) -GuestCredential $GuestCreds -ScriptType Powershell -ScriptText $GetDNSAddress
    $SO.ScriptOutput
}

function Set-DNSServerAddress {
    $TargetVM = Read-Host -Prompt "Enter the name of the VM: "
    Write-Host "Setting DNS Server Addresses on $TargetVM..." -ForegroundColor Blue -BackgroundColor Black
    $SO = Invoke-VMScript -VM ($TargetVM) -GuestCredential $GuestCreds -ScriptType Powershell -ScriptText $SetDNSAddress
    $SO.ScriptOutput
    Write-Host "DNS Server Addresses on $TargetVM have been updated." -ForegroundColor DarkGreen -BackgroundColor Black
}

function Set-DNSServerAddressAll {
    Write-Host "Setting DNS Server Addresses on $VM..." -ForegroundColor Blue -BackgroundColor Black
    $SO = Invoke-VMScript -VM ($VM) -GuestCredential $GuestCreds -ScriptType Powershell -ScriptText $SetDNSAddress
    $SO.ScriptOutput
    Write-Host "DNS Server Addresses on $VM have been updated." -ForegroundColor DarkGreen -BackgroundColor Black
}

function Invoke-RegisterDNS {
    $TargetVM = Read-Host -Prompt "Enter the name of the VM: "
    Write-Host "Registering DNS on $TargetVM" -ForegroundColor DarkGreen -BackgroundColor Black
    $SO = Invoke-VMScript -VM ($TargetVM) -GuestCredential $GuestCreds -ScriptType Powershell -ScriptText $RegisterDNS
    $SO.ScriptOutput
}

function Invoke-RegisterDNSAll {
    Write-Host "Registering DNS on $VM" -ForegroundColor DarkGreen -BackgroundColor Black
    $SO = Invoke-VMScript -VM ($VM) -GuestCredential $GuestCreds -ScriptType Powershell -ScriptText $RegisterDNS
    $SO.ScriptOutput
}

<# WINDOWS SERVICES #>
function Get-ServicesOnVM {
    $TargetVM = Read-Host -Prompt "Enter the name of the VM: "
    Write-Host "Getting List of all Services on $TargetVM"
    $SO = Invoke-VMScript -VM ($TargetVM) -GuestCredential $GuestCreds -ScriptType Powershell -ScriptText $GetSvcOnVM
    $SO.ScriptOutput
}

function Get-ServicesAll {
    Write-Host "Getting List of all Services on $VM"
    $SO = Invoke-VMScript -VM ($VM) -GuestCredential $GuestCreds -ScriptType Powershell -ScriptText $GetSvcOnVM
    $SO.ScriptOutput
}

function Get-SpecificSVC {
    $TargetVM = Read-Host -Prompt "Enter the name of the VM: "
    Write-Host "Finding Service on $TargetVM"
    $SO1 = Invoke-VMScript -VM ($TargetVM) -GuestCredential $GuestCreds -ScriptType Powershell -ScriptText $GetDomainSvc
    if (-not [string]::IsNullOrWhiteSpace($SO1.ScriptOutput)) {
        Write-Host "Service Found on $TargetVM" -ForegroundColor Red -BackgroundColor Black
        $SO1.ScriptOutput
    } else {
        Write-Host "Service not Found on $TargetVM" -ForegroundColor DarkGreen -BackgroundColor Black
    }
}

function Get-SpecificSVCAll {
    Write-Host "Finding Service on $VM"
    $SO1 = Invoke-VMScript -VM ($VM) -GuestCredential $GuestCreds -ScriptType Powershell -ScriptText $GetDomainSvc
    if (-not [string]::IsNullOrWhiteSpace($SO1.ScriptOutput)) {
        Write-Host "Service Found on $VM" -ForegroundColor Red -BackgroundColor Black
        $SO1.ScriptOutput
    } else {
        Write-Host "Service not Found on $VM" -ForegroundColor DarkGreen -BackgroundColor Black
    }
}

<# NETWORK CONNECTIVITY #>
function Get-PingStatus {
    $TargetVM = Read-Host -Prompt "Enter the name of the VM: "
    Write-Host "Pinging $TargetVM" -ForegroundColor DarkGreen -BackgroundColor Black
    Test-Connection -TargetName $TargetVM -ResolveDestination | Select-Object -ExpandProperty Status
}

function Get-PingStatusAll {
    Write-Host "Pinging $VM" -ForegroundColor DarkGreen -BackgroundColor Black
    Test-Connection -TargetName $VM -ResolveDestination | Select-Object -ExpandProperty Status
}

function Get-PingStatusIP {
    $TargetVM = Read-Host -Prompt "Enter the name of the VM: "
    Write-Host "Pinging IP of $TargetVM" -ForegroundColor DarkGreen -BackgroundColor Black
    $IP = Get-PrimaryIPv4Address -VMName $TargetVM
    Test-Connection -TargetName $IP -IPv4 -ResolveDestination | Select-Object -ExpandProperty Status
}

function Get-PingStatusIPAll {
    Write-Host "Pinging IP of $VM" -ForegroundColor DarkGreen -BackgroundColor Black
    $IP = Get-PrimaryIPv4Address -VMName $VM
    Test-Connection -TargetName $IP -IPv4 -ResolveDestination | Select-Object -ExpandProperty Status
}

function Get-PingStatusAdmin {
    $TargetVM = Read-Host -Prompt "Enter the name of the VM: "
    Write-Host "Checking Admin Share on $TargetVM" -ForegroundColor DarkGreen -BackgroundColor Black
    Show-AdminShareStatus -ComputerName $TargetVM
}

function Get-PingStatusAdminAll {
    Write-Host "Checking Admin Share on $VM" -ForegroundColor DarkGreen -BackgroundColor Black
    Show-AdminShareStatus -ComputerName $VM
}

function Test-ReachDomain {
    $TargetVM = Read-Host -Prompt "Enter the name of the VM: "
    Write-Host "Testing $DC.$Domain reachability from $TargetVM" -ForegroundColor DarkGreen -BackgroundColor Black
    $SO = Invoke-VMScript -VM ($TargetVM) -GuestCredential $GuestCreds -ScriptType Powershell -ScriptText $PingDC
    $SO.ScriptOutput
}

function Test-ReachDomainAll {
    Write-Host "Testing $DC.$Domain reachability from $VM" -ForegroundColor DarkGreen -BackgroundColor Black
    $SO = Invoke-VMScript -VM ($VM) -GuestCredential $GuestCreds -ScriptType Powershell -ScriptText $PingDC
    $SO.ScriptOutput
}

function Test-ReachDomainDCIP {
    Write-Host "Testing $DCIP reachability from $VM" -ForegroundColor DarkGreen -BackgroundColor Black
    $SO = Invoke-VMScript -VM ($VM) -GuestCredential $GuestCreds -ScriptType Powershell -ScriptText $PingDCIP
    $SO.ScriptOutput
}

function Test-ADMTPort {
    $TargetVM = Read-Host -Prompt "Enter the name of the VM: "
    Write-Host "Checking ADMT-related ports from $TargetVM to $DCIP" -ForegroundColor DarkGreen -BackgroundColor Black
    $SO = Invoke-VMScript -VM ($TargetVM) -GuestCredential $GuestCreds -ScriptType Powershell -ScriptText $TestADMTPortsScript
    $SO.ScriptOutput
}

function Test-ADMTPortsAll {
    Write-Host "Checking ADMT-related ports from $VM to $DCIP" -ForegroundColor DarkGreen -BackgroundColor Black
    $SO = Invoke-VMScript -VM ($VM) -GuestCredential $GuestCreds -ScriptType Powershell -ScriptText $TestADMTPortsScript
    $SO.ScriptOutput
}

<# WINDOWS FIREWALL #>
function Get-WinFirewallStatus {
    $TargetVM = Read-Host -Prompt "Enter the name of the VM: "
    Write-Host "Getting Firewall Status on $TargetVM" -ForegroundColor DarkGreen -BackgroundColor Black
    $SO = Invoke-VMScript -VM ($TargetVM) -GuestCredential $GuestCreds -ScriptType Powershell -ScriptText $FWStatus
    $SO.ScriptOutput
}

function Get-WinFirewallStatusAll {
    Write-Host "Getting Firewall Status on $VM" -ForegroundColor DarkGreen -BackgroundColor Black
    $SO = Invoke-VMScript -VM ($VM) -GuestCredential $GuestCreds -ScriptType Powershell -ScriptText $FWStatus
    $SO.ScriptOutput
}

function Set-WinFirewallOff {
    $TargetVM = Read-Host -Prompt "Enter the name of the VM: "
    Write-Host "Disabling Windows Firewall on $TargetVM" -ForegroundColor Blue -BackgroundColor Black
    $SO = Invoke-VMScript -VM ($TargetVM) -GuestCredential $GuestCreds -ScriptType Powershell -ScriptText $FWDisable
    $SO.ScriptOutput
}

function Set-WinFirewallOffAll {
    Write-Host "Disabling Windows Firewall on $VM" -ForegroundColor Blue -BackgroundColor Black
    $SO = Invoke-VMScript -VM ($VM) -GuestCredential $GuestCreds -ScriptType Powershell -ScriptText $FWDisable
    $SO.ScriptOutput
}

<# BACKUP FUNCTIONS #>
function Show-BackupPolicyExclude {
    $TargetVM = Read-Host -Prompt "Enter the name of the VM: "
    Write-Host "Checking Backup Policy on $TargetVM"
    $BUExclude = Get-Annotation -Entity $TargetVM -CustomAttribute "BackupPolicy" | Select-Object Value
    if ($BUExclude.Value -eq "Exclude") {
        Write-Host "Backup Policy on $TargetVM set to Exclude" -ForegroundColor DarkGreen -BackgroundColor Black
    } else {
        Write-Host "Backup Policy on $TargetVM NOT set to Exclude" -ForegroundColor Red -BackgroundColor Black
    }
}

function Show-BackupPolicyExcludeAll {
    Write-Host "Checking Backup Policy on $VM"
    $BUExclude = Get-Annotation -Entity $VM -CustomAttribute "BackupPolicy" | Select-Object Value
    if ($BUExclude.Value -eq "Exclude") {
        Write-Host "Backup Policy on $VM set to Exclude" -ForegroundColor DarkGreen -BackgroundColor Black
    } else {
        Write-Host "Backup Policy on $VM NOT set to Exclude" -ForegroundColor Red -BackgroundColor Black
    }
}

function Show-BackupPolicySnapshot {
    $TargetVM = Read-Host -Prompt "Enter the name of the VM: "
    Write-Host "Checking Backup Policy on $TargetVM"
    $BUSnapshot = Get-Annotation -Entity $TargetVM -CustomAttribute "BackupPolicy" | Select-Object Value
    if ($BUSnapshot.Value -eq "Snapshot") {
        Write-Host "Backup Policy on $TargetVM set to Snapshot" -ForegroundColor DarkGreen -BackgroundColor Black
    } else {
        Write-Host "Backup Policy on $TargetVM NOT set to Snapshot" -ForegroundColor Red -BackgroundColor Black
    }
}

function Show-BackupPolicySnapshotAll {
    Write-Host "Checking Backup Policy on $VM"
    $BUSnapshot = Get-Annotation -Entity $VM -CustomAttribute "BackupPolicy" | Select-Object Value
    if ($BUSnapshot.Value -eq "Snapshot") {
        Write-Host "Backup Policy on $VM set to Snapshot" -ForegroundColor DarkGreen -BackgroundColor Black
    } else {
        Write-Host "Backup Policy on $VM NOT set to Snapshot" -ForegroundColor Red -BackgroundColor Black
    }
}

function Set-BackupPolicy2Exclude {
    $TargetVM = Read-Host -Prompt "Enter the name of the VM: "
    Write-Host "Setting VMs Backup Policy to Exclude"
    if ((Get-Annotation -Entity $TargetVM -CustomAttribute "BackupPolicy" | Select-Object -ExpandProperty Value) -ne "Exclude") {
            Write-Host "Setting Backup Policy on $TargetVM to Exclude" -ForegroundColor Blue -BackgroundColor Black
            Set-Annotation -Entity $TargetVM -CustomAttribute "BackupPolicy" -Value "Exclude"
        }
    Write-Host "Finished setting Backup Policy on $TargetVM" -ForegroundColor DarkGreen -BackgroundColor Black
}

function Set-BackupPolicy2ExcludeAll {
    Write-Host "Setting VMs Backup Policy to Exclude"
    if ((Get-Annotation -Entity $VM -CustomAttribute "BackupPolicy" | Select-Object -ExpandProperty Value) -ne "Exclude") {
            Write-Host "Setting Backup Policy on $VM to Exclude" -ForegroundColor Blue -BackgroundColor Black
            Set-Annotation -Entity $VM -CustomAttribute "BackupPolicy" -Value "Exclude"
        }
    Write-Host "Finished setting Backup Policy on $VM" -ForegroundColor DarkGreen -BackgroundColor Black
}

function Set-BackupPolicy2Snapshot {
    $TargetVM = Read-Host -Prompt "Enter the name of the VM: "
    Write-Host "Setting VMs Backup Policy to Snapshot"
    if ((Get-Annotation -Entity $TargetVM -CustomAttribute "BackupPolicy" | Select-Object -ExpandProperty Value) -ne "Snapshot") {
            Write-Host "Setting Backup Policy on $TargetVM to Snapshot" -ForegroundColor Blue -BackgroundColor Black
            Set-Annotation -Entity $TargetVM -CustomAttribute "BackupPolicy" -Value "Snapshot"
        }
    Write-Host "Finished setting Backup Policy on $TargetVM" -ForegroundColor DarkGreen -BackgroundColor Black
}

function Set-BackupPolicy2SnapshotAll {
    Write-Host "Setting VMs Backup Policy to Snapshot"
    if ((Get-Annotation -Entity $VM -CustomAttribute "BackupPolicy" | Select-Object -ExpandProperty Value) -ne "Snapshot") {
            Write-Host "Setting Backup Policy on $VM to Snapshot" -ForegroundColor Blue -BackgroundColor Black
            Set-Annotation -Entity $VM -CustomAttribute "BackupPolicy" -Value "Snapshot"
        }
    Write-Host "Finished setting Backup Policy on $VM" -ForegroundColor DarkGreen -BackgroundColor Black
}

<# SNAPSHOT FUNCTIONS #>
function New-Snap4Salvation {
    $TargetVM = Read-Host -Prompt "Enter the name of the VM: "
    Write-Host "Creating new snapshot of $TargetVM" -ForegroundColor Blue -BackgroundColor Black
    New-Snapshot -VM $TargetVM -Name "$TargetVM.SNAPSHOT" -Description "Snapshot" -Quiesce -Memory:$false -Confirm:$false
    Write-Host "Finished creating new snapshot of $TargetVM" -ForegroundColor DarkGreen -BackgroundColor Black
}

function New-Snap4SalvationAll {
    Write-Host "Creating new snapshot of $VM" -ForegroundColor Blue -BackgroundColor Black
    New-Snapshot -VM $VM -Name "$VM.SNAPSHOT" -Description "Snapshot" -Quiesce -Memory:$false -Confirm:$false
    Write-Host "Finished creating new snapshot of $VM" -ForegroundColor DarkGreen -BackgroundColor Black
}

function Remove-AllSnapshots4VM {
    $TargetVM = Read-Host -Prompt "Enter the name of the VM: "
    Write-Host "Removing Snapshots for $TargetVM" -ForegroundColor Blue -BackgroundColor Black
    (VMware.VimAutomation.Core\Get-VM $TargetVM) | Get-Snapshot | ForEach-Object {Remove-Snapshot $_ -Confirm:$false}
    Write-Host "Finished removing Snapshots for $TargetVM" -ForegroundColor DarkGreen -BackgroundColor Black

}

function Remove-AllSnapshots4All {
    Write-Host "Removing Snapshots for each $VM" -ForegroundColor Blue -BackgroundColor Black
    (VMware.VimAutomation.Core\Get-VM $VM) | Get-Snapshot | ForEach-Object {Remove-Snapshot $_ -Confirm:$false}
    Write-Host "Finished removing Snapshots for $VM" -ForegroundColor DarkGreen -BackgroundColor Black
}

<# MANUAL MOVE FUNCTIONS #>
function Add-VM2NewDomain {
    $TargetVM = Read-Host -Prompt "Enter the name of the VM: "
    Write-Host "Moving $TargetVM to new domain..." -ForegroundColor Blue -BackgroundColor Black
    $SO = Invoke-VMScript -VM ($TargetVM) -GuestCredential $ADMTCreds -ScriptType Powershell -ScriptText $ManualMoveScript
    $SO.ScriptOutput
    Write-Host "Done!" -ForegroundColor Green -BackgroundColor Black
}

function Add-VM2NewDomainAll {
    Write-Host "Moving $VM to new domain..." -ForegroundColor Blue -BackgroundColor Black
    $SO = Invoke-VMScript -VM ($VM) -GuestCredential $ADMTCreds -ScriptType Powershell -ScriptText $ManualMoveScript
    $SO.ScriptOutput
    Write-Host "Done!" -ForegroundColor Green -BackgroundColor Black
}

<# VMWARE TOOLS STATUS #>
function Get-VMwareToolsStatusOfVM {
    $TargetVM = Read-Host -Prompt "Enter the name of the VM: "
    Write-Host "Getting VMware Tools Status of $TargetVM" -ForegroundColor Blue -BackgroundColor Black
    ((VMware.VimAutomation.Core\Get-VM $TargetVM) | Get-View).Guest.ToolsStatus
}

function Get-VMwareToolsStatusOfVMAll {
    Write-Host "Getting VMware Tools Status of $VM" -ForegroundColor DarkGreen -BackgroundColor Black
    ((VMware.VimAutomation.Core\Get-VM $VM) | Get-View).Guest.ToolsStatus
}

function Update-VmWareToolsOnVM {
    $TargetVM = Read-Host -Prompt "Enter the name of the VM: "
    Write-Host "Updating VmWare Tools on $TargetVM" -ForegroundColor Blue -BackgroundColor Black
    (VMware.VimAutomation.Core\Get-VM $TargetVM) | Update-Tools -NoReboot
}

function Update-VmWareToolsOnVMAll {
    Write-Host "Updating VmWare Tools on $VM" -ForegroundColor DarkGreen -BackgroundColor Black
    (VMware.VimAutomation.Core\Get-VM $VM) | Update-Tools -NoReboot
}

<# VM POWER AND REBOOT #>
function Get-PowerStatusOfVM {
    $TargetVM = Read-Host -Prompt "Enter the name of the VM: "
    Write-Host "Getting Power Status of $TargetVM" -ForegroundColor Blue -BackgroundColor Black
    (VMware.VimAutomation.Core\Get-VM $TargetVM) | Select-Object Powerstate
}

function Get-PowerStatusOfVMAll {
    Write-Host "Getting Power Status of $VM" -ForegroundColor DarkGreen -BackgroundColor Black
    (VMware.VimAutomation.Core\Get-VM $VM) | Select-Object Powerstate
}

function Invoke-RebootOfVM {
    $TargetVM = Read-Host -Prompt "Enter the name of the VM: "
    Write-Host "Restarting $TargetVM" -ForegroundColor Blue -BackgroundColor Black
    Restart-VMGuest -VM $TargetVM
}

function Start-PoweredOffVM {
    $TargetVM = Read-Host -Prompt "Enter the name of the VM: "
    Write-Host "Starting $TargetVM" -ForegroundColor Blue -BackgroundColor Black
    Start-VM -VM $TargetVM -Confirm:$false
}

function Invoke-ShutdownOfVM {
    $TargetVM = Read-Host -Prompt "Enter the name of the VM: "
    Write-Host "Shutting down $TargetVM" -ForegroundColor Blue -BackgroundColor Black
    Stop-VMGuest -VM $TargetVM -Confirm:$False
}

function Invoke-PowerOffOfVM {
    $TargetVM = Read-Host -Prompt "Enter the name of the VM: "
    Write-Host "Powering off $TargetVM" -ForegroundColor Blue -BackgroundColor Black
    Stop-VM -VM $TargetVM -Confirm:$False
}

<# VMOTION #>
function Get-VMotion {
    param (
        [Parameter(Mandatory, ValueFromPipeline)]
        [object]$VM,

        [int]$Days = 1
    )

    process {
        $ResolvedVM = if ($VM -is [string]) {
            VMware.VimAutomation.Core\Get-VM -Name $VM -ErrorAction Stop
        } else {
            $VM
        }

        Get-VIEvent -Entity $ResolvedVM -Start (Get-Date).AddDays(-$Days) |
            Where-Object {
                $_.FullFormattedMessage -match '(?i)vmotion|migrat' -or
                $_.GetType().Name -match 'Migrat'
            } |
            Select-Object CreatedTime, UserName, FullFormattedMessage
    }
}

function Get-DailyVmotion4VM {
    $TargetVM = Read-Host -Prompt "Enter the name of the VM: "
    Write-Host "Getting 24-hour vMotion events for $TargetVM" -ForegroundColor DarkGreen -BackgroundColor Black
    (VMware.VimAutomation.Core\Get-VM $TargetVM) | Get-VMotion -Days 1 | Format-List *
}

function Get-DailyVmotion4All {
    Write-Host "Getting 24-hour vMotion events for $VM" -ForegroundColor DarkGreen -BackgroundColor Black
    (VMware.VimAutomation.Core\Get-VM $VM) | Get-VMotion -Days 1 | Format-List *
}

function Get-WeeklyVmotion4VM {
    $TargetVM = Read-Host -Prompt "Enter the name of the VM: "
    Write-Host "Getting 1-week vMotion events for $TargetVM" -ForegroundColor DarkGreen -BackgroundColor Black
    (VMware.VimAutomation.Core\Get-VM $TargetVM) | Get-VMotion -Days 7 | Format-List *
}

function Get-WeeklyVmotion4All {
    Write-Host "Getting 1-week vMotion events for $VM" -ForegroundColor DarkGreen -BackgroundColor Black
    (VMware.VimAutomation.Core\Get-VM $VM) | Get-VMotion -Days 7 | Format-List *
}

<# EXECUTE INTERACTIVE MENU #>
do {
    Show-Menu
    $selection = Read-Host "Please make a selection"
    switch ($selection) {
        <# VCENTER AND LIST VERIFICATION #>
        '1' {
            'Connecting to vCenter...'
            Connect-2vCenter
        }
        '2' {
            'Disconnecting from vCenter...'
            Disconnect-VIServer -Server * -Force -Confirm:$false
        }
        '3' {
            'Getting list of VMs...'
            Get-Content -Path $VMListPath
        }
        '4' {
            'Checking list of VMs for existence in vCenter...'
            foreach ($VM in $VMs) {
                Get-LocationOfVMs
            }
        }

        <# WINDOWS ADMIN ACCOUNTS #>
        '11a' {
            'Getting users in Admins group on specific VM...'
            Get-UsersInAdminGroup
        }
        '11b' {
            'Getting users in Admins group on each VM...'
            foreach ($VM in $VMs) {
                Get-UsersInAdminGroupAll
            }
        }
        '12a' {
            'Adding ADMT account to Admins group on specific VM...'
            Add-Account2Group
        }
        '12b' {
            'Adding ADMT account to Admins group on each VM...'
            foreach ($VM in $VMs) {
                Add-Account2GroupAll
            }
        }
        '13a' {
            'Testing authentication of ADMT account...'
            Test-ADAuthentication
        }

        <# IP AND DNS ADDRESSES #>
        '21a' {
            'Getting IP Address for each VM...'
            Get-IPAddress4VM
        }
        '21b' {
            'Getting IP Address for each VM...'
            foreach ($VM in $VMs) {
                Get-IPAddress4VMAll
            }
        }
        '22a' {
            'Getting Domain for each VM...'
            Get-DomainOnVM
        }
        '22b' {
            'Getting Domain for each VM...'
            foreach ($VM in $VMs) {
                Get-DomainOnVMAll
            }
        }
        '23a' {
            'Getting DNS Server Address on specific VM...'
            Get-DNSServerAddress
        }
        '23b' {
            'Getting DNS Server Address for each VM...'
            foreach ($VM in $VMs) {
                Get-DNSServerAddressAll
            }
        }
        '24a' {
            'Setting the DNS Server Address on specific VM...'
            Set-DNSServerAddress
        }
        '24b' {
            'Setting the DNS Server Address on each VM...'
            foreach ($VM in $VMs) {
                Set-DNSServerAddressAll
            }
        }
        '25a' {
            'Registering DNS on specific VM...'
            Invoke-RegisterDNS
        }
        '25b' {
            'Registering DNS on each VM...'
            foreach ($VM in $VMs) {
                Invoke-RegisterDNSAll
            }
        }

        <# WINDOWS SERVICES #>
        '31a' {
            'Getting list of all Services on specific VM...'
            Get-ServicesOnVM
        }
        '31b' {
            'Getting list of all Services on each VM...'
            foreach ($VM in $VMs) {
                Get-ServicesAll
            }
        }
        '32a' {
            'Finding Service on specific VM...'
            Get-SpecificSVC
        }
        '32b' {
            'Finding Service on each VM...'
            foreach ($VM in $VMs) {
                Get-SpecificSVCAll
            }
        }

        <# NETWORK CONNECTIVITY #>
        '41a' {
            'Pinging specific VM by ComputerName...'
            Get-PingStatus
        }
        '41b' {
            'Pinging each VM by ComputerName...'
            foreach ($VM in $VMs) {
                Get-PingStatusAll
            }
        }
        '42a' {
            'Pinging specific VM by IP...'
            Get-PingStatusIP
        }
        '42b' {
            'Pinging each VM by IP...'
            foreach ($VM in $VMs) {
                Get-PingStatusIPAll
            }
        }
        '43a' {
            'Pinging the Admin share on each VM...'
            Get-PingStatusAdmin
        }
        '43b' {
            'Pinging the Admin share on each VM...'
            foreach ($VM in $VMs) {
                Get-PingStatusAdminAll
            }
        }
        '44a' {
            'Testing reachability of DC on specific VM...'
            Test-ReachDomain
        }
        '44b' {
            'Testing reachability of DC from each VM...'
            foreach ($VM in $VMs) {
                Test-ReachDomainAll
            }
        }
        '44c' {
            'Testing reachability of DC IP from each VM...'
            foreach ($VM in $VMs) {
                Test-ReachDomainDCIP
            }
        }

        <# WINDOWS FIREWALL #>
        '51a' {
            'Getting status of Windows Firewall on specific VM...'
            Get-WinFirewallStatus
        }
        '51b' {
            'Getting status of Windows Firewall on each VM...'
            foreach ($VM in $VMs) {
                Get-WinFirewallStatusAll
            }
        }
        '52a' {
            'Disabling Windows Firewall on specific VM...'
            Set-WinFirewallOff
        }
        '52b' {
            'Disabling Windows Firewall on each VM...'
            foreach ($VM in $VMs) {
                Set-WinFirewallOffAll
            }
        }

        <# BACKUP POLICY #>
        '61a' {
            'Show list of VMs with Backup Policy set to Exclude...'
            Show-BackupPolicyExclude
        }
        '61b' {
            'Show list of VMs with Backup Policy set to Exclude...'
            foreach ($VM in $VMs) {
                Show-BackupPolicyExcludeAll
            }
        }
        '62a' {
            'Show list of VMs with Backup Policy set to Snapshot...'
            Show-BackupPolicySnapshot
        }
        '62b' {
            'Show list of VMs with Backup Policy set to Snapshot...'
            foreach ($VM in $VMs) {
                Show-BackupPolicySnapshotAll
            }
        }
        '64a' {
            'Set Backup Policy to Exclude on each VM...'
            Set-BackupPolicy2Exclude
        }
        '64b' {
            'Set Backup Policy to Exclude on each VM...'
            foreach ($VM in $VMs) {
                Set-BackupPolicy2ExcludeAll
            }
        }
        '65a' {
            'Set Backup Policy to Snapshot on each VM...'
            Set-BackupPolicy2Snapshot
        }
        '65b' {
            'Set Backup Policy to Snapshot on each VM...'
            foreach ($VM in $VMs) {
                Set-BackupPolicy2SnapshotAll
            }
        }

        <# SNAPSHOTS #>
        '71a' {
            'Take Snapshot of specific VM...'
            New-Snap4Salvation
        }
        '71b' {
            'Take Snapshot of each VM...'
            foreach ($VM in $VMs) {
                New-Snap4SalvationAll
            }
        }
        '72a' {
            'Remove Snapshots of specific VM...'
            Remove-AllSnapshots4VM
        }
        '72b' {
            'Remove Snapshots of each VM...'
            foreach ($VM in $VMs) {
                Remove-AllSnapshots4All
            }
        }

        <# MANUAL MOVES #>
        '81a' {
            'Manually moving specific VM...'
            Add-VM2NewDomain
        }
        '81b' {
            'Manually moving each VM...'
            foreach ($VM in $VMs) {
                Add-VM2NewDomainAll
            }
        }

        <# VMWARE TOOLS STATUS #>
        '91a' {
            'Getting VMware Tools Status on VM...'
            Get-VMwareToolsStatusOfVM
        }
        '91b' {
            'Getting VMware Tools Status on VMs...'
            foreach ($VM in $VMs) {
                Get-VMwareToolsStatusOfVMAll
            }
        }
        '92a' {
            'Updating VMware Tools on VM...'
            Update-VmWareToolsOnVM
        }
        '92b' {
            'Updating VMware Tools on VMs...'
            foreach ($VM in $VMs) {
                Update-VmWareToolsOnVMAll
            }
        }

        <# VM POWER AND REBOOT #>
        '101a' {
            'Getting Power Status of VM...'
            Get-PowerStatusOfVM
        }
        '101b' {
            'Getting Power Status of VMs...'
            foreach ($VM in $VMs) {
                Get-PowerStatusOfVMAll
            }
        }
        '102A' {
            'Getting list of VMs...'
            Invoke-RebootOfVM
        }
        '103A' {
            'Powering On specific VM...'
            Start-PoweredOffVM
        }
        '104A' {
            'Shutting Down specific VM...'
            Invoke-ShutdownOfVM
        }
        '105A' {
            'Powering Off specific VM...'
            Invoke-PowerOffOfVM
        }

        <# VMOTION#>
        '111a' {
            'Getting 24-hour vMotion events of VM...'
            Get-DailyVmotion4VM
        }
        '111b' {
            'Getting 24-hour vMotion events of VMs...'
            foreach ($VM in $VMs) {
                Get-DailyVmotion4All
            }
        }
        '112a' {
            'Getting 1-week vMotion events of VM...'
            Get-WeeklyVmotion4VM
        }
        '112b' {
            'Getting 1-week vMotion events of VMs...'
            foreach ($VM in $VMs) {
                Get-WeeklyVmotion4All
            }
        }

        <# VM CPU AND MEMORY #>
        '121a' {
            'Checking CPU and Memory on VM...'
            Get-WeeklyCPURAM4VM
        }
        '121b' {
            'Checking CPU and Memory on VMs...'
            foreach ($VM in $VMs) {
                Get-WeeklyCPURAM4All
            }
        }
        '122a' {
            'Checking CPU and Memory on VM...'
            Get-MonthlyCPURAM4VM
        }
        '122b' {
            'Checking CPU and Memory on VMs...'
            foreach ($VM in $VMs) {
                Get-MonthlyCPURAM4All
            }
        }
    }
    pause
}
until (
    $selection -eq 'q'
)
