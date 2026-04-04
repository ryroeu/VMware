# Deploy Windows Server 2019/2022 in vCenter
#### USER DEFINED VARIABLES ############################################################################################
$Domain = ""              #AD Domain to join
$vCenterInstance = ""     #vCenter to deploy VM
$Cluster = ""             #vCenter cluster to deploy VM
$VMTemplate = ""          #vCenter template to deploy VM
$CustomSpec = ""          #vCenter customization to use for VM
$Location = ""            #Folderlocation in vCenter for VM
$DataStore = ""           #Datastore in vCenter to use for VM
$DiskStorageFormat = ""   #Diskformtat to use (Thin / Thick) for VM
$NetworkName = ""         #Portgroup to use for VM
$Memory =                 #Memory of VM In GB
$CPU =                    #number of vCPUs of VM
$DiskCapacity =           #Disksize of VM in GB
$SubnetLength =           #Subnetlength IP address to use (24 means /24 or 255.255.255.0) for VM
$GW = ""                  #Gateway to use for VM
$IP_DNS = ""              #IP address DNS server to use

### FUNCTION DEFINITIONS ################################################################################################
function Import-PowerCLIModule {
    foreach ($moduleName in "VCF.PowerCLI", "VMware.PowerCLI") {
        if (Get-Module -ListAvailable -Name $moduleName) {
            Import-Module $moduleName -ErrorAction Stop
            return $moduleName
        }
    }

    throw "Neither VCF.PowerCLI nor VMware.PowerCLI is installed."
}

function ConvertTo-EncodedGuestPowerShellCommand {
    param(
        [Parameter(Mandatory=$true)]
        [string]$ScriptText
    )

    [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($ScriptText))
}

function New-WindowsPowerShellGuestCommand {
    param(
        [Parameter(Mandatory=$true)]
        [string]$ScriptText
    )

    $encodedCommand = ConvertTo-EncodedGuestPowerShellCommand -ScriptText $ScriptText
    "%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass -EncodedCommand $encodedCommand"
}

function Start-Customization([string]$VM) {
    Write-Host "Verifying that customization for VM $VM has started"
    $i = 60 # time-out of 5 min
    while ($i -gt 0) {
        $vmEvents = Get-VIEvent -Entity $VM
        $startedEvent = $vmEvents | Where-Object {$_.GetType().Name -eq "CustomizationStartedEvent"}
        if ($startedEvent) {
            Write-Host "Customization for VM $VM has started"
            return $true
        }

        Start-Sleep -Seconds 5
        $i--
    }

    Write-Warning "Customization for VM $VM has failed"
    return $false
}

function Stop-Customizaton([string]$VM) {
    Write-Host "Verifying that customization for VM $VM has finished"
    $i = 60 # time-out of 5 min
    while ($true) {
        $vmEvents = Get-VIEvent -Entity $VM
        $SucceededEvent = $vmEvents | Where-Object {$_.GetType().Name -eq "CustomizationSucceeded"}
        $FailureEvent = $vmEvents | Where-Object {$_.GetType().Name -eq "CustomizationFailed"}
        if ($FailureEvent -or ($i -eq 0)) {
            Write-Warning "Customization of VM $VM failed"
            return $false
        }

        if ($SucceededEvent) {
            Write-Host "Customization of VM $VM completed successfully"
            Start-Sleep -Seconds 30
            Write-Host "Waiting for VM $VM to complete post-customization reboot"
            Wait-Tools -VM $VM -TimeoutSeconds 300 | Out-Null
            Start-Sleep -Seconds 30
            return $true
        }

        Start-Sleep -Seconds 5
        $i--
    }
}

function Restart-VM([string]$VM) {
    Restart-VMGuest -VM $VM -Confirm:$false | Out-Null
    Write-Host "Reboot VM $VM"
    Start-Sleep -Seconds 60
    Wait-Tools -VM $VM -TimeoutSeconds 300 | Out-Null
    Start-Sleep -Seconds 10
}

function Add-Script([string]$ScriptText, $Parameters=@(), [bool]$Reboot=$false, [string]$ScriptType="PowerShell") {
    $i = 1
    foreach ($parameter in $Parameters) {
        if ($parameter -is [string]) {
            $ScriptText = $ScriptText.Replace("%" + [string]$i, '"' + $parameter + '"')
        } else {
            $ScriptText = $ScriptText.Replace("%" + [string]$i, [string]$parameter)
        }
        $i++
    }

    $script:scripts += [pscustomobject]@{
        ScriptText = $ScriptText
        Reboot     = $Reboot
        ScriptType = $ScriptType
    }
}

function Test-IP([string]$IP) {
    if (-not $IP -or ([bool]($IP -as [IPAddress]))) {
        return $true
    }

    return $false
}

#### USER INTERACTIONS ##############################################################################################
Clear-Host
Write-Host "Deploy Windows server" -ForegroundColor Red
$Hostname = Read-Host -Prompt "Hostname"
if ($Hostname.Length -gt 15) {
    Write-Host -ForegroundColor Red "$Hostname is an invalid hostname"
    break
}

$IP = Read-Host -Prompt "IP Address (press ENTER for DHCP)"
if (-not (Test-IP $IP)) {
    Write-Host -ForegroundColor Red "$IP is an invalid address"
    break
}

$JoinDomainYN = Read-Host "Join Domain $Domain (Y/N)"

### READ CREDENTIALS ########################################################################################################
$VMLocalCredential = Get-Credential -UserName "$Hostname\Administrator" -Message "Enter local Administrator credentials for the deployed VM"
$vCenterCredential = Get-Credential -Message "Enter vCenter credentials"
if ($JoinDomainYN.ToUpper() -eq "Y") {
    $DomainCredential = Get-Credential -Message "Enter domain join credentials for $Domain"
    $DomainAdmin = $DomainCredential.UserName
    $DomainAdminPassword = $DomainCredential.GetNetworkCredential().Password
}

### CONNECT TO VCENTER ##############################################################################################
Import-PowerCLIModule | Out-Null
Connect-VIServer -Server $vCenterInstance -Credential $vCenterCredential -WarningAction SilentlyContinue
$SourceVMTemplate = Get-Template -Name $VMTemplate
$SourceCustomSpec = Get-OSCustomizationSpec -Name $CustomSpec

### DEFINE POWERSHELL SCRIPTS TO RUN IN VM AFTER DEPLOYMENT ############################################################################################################
if ($IP) {
    Add-Script "New-NetIPAddress -InterfaceIndex 2 -IPAddress %1 -PrefixLength %2 -DefaultGateway %3" @($IP, $SubnetLength, $GW)
    Add-Script "Set-DnsClientServerAddress -InterfaceIndex 2 -ServerAddresses %1" @($IP_DNS)
}

if ($JoinDomainYN.ToUpper() -eq "Y") {
    $escapedDomainUser = ("$Domain\$DomainAdmin").Replace("'", "''")
    $escapedDomainPassword = $DomainAdminPassword.Replace("'", "''")
    $escapedDomainName = $Domain.Replace("'", "''")
    $domainJoinScript = @'
$DomainUser = %1
$DomainPWord = ConvertTo-SecureString -String %2 -AsPlainText -Force
$DomainCredential = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $DomainUser, $DomainPWord
Add-Computer -DomainName %3 -Credential $DomainCredential
Restart-Computer -Force
'@
    $domainJoinScript = $domainJoinScript.Replace("%1", "'" + $escapedDomainUser + "'")
    $domainJoinScript = $domainJoinScript.Replace("%2", "'" + $escapedDomainPassword + "'")
    $domainJoinScript = $domainJoinScript.Replace("%3", "'" + $escapedDomainName + "'")
    Add-Script (New-WindowsPowerShellGuestCommand -ScriptText $domainJoinScript) @() $true "Bat"
}

Add-Script 'Import-Module NetSecurity; Set-NetFirewallRule -DisplayGroup "File and Printer Sharing" -Enabled True'
Add-Script 'Set-ItemProperty -Path "HKLM:\System\CurrentControlSet\Control\Terminal Server" -Name fDenyTSConnections -Value 0;
            Enable-NetFirewallRule -DisplayGroup "Remote Desktop";
            Set-ItemProperty -Path "HKLM:\System\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp" -Name UserAuthentication -Value 0'

### DEPLOY VM ###############################################################################################################################################################
Write-Host "Deploying virtual machine with name: [$Hostname] using template: [$SourceVMTemplate] and customization specification: [$SourceCustomSpec] on cluster: [$Cluster]"
New-VM -Name $Hostname -Template $SourceVMTemplate -ResourcePool $Cluster -OSCustomizationSpec $SourceCustomSpec -Location $Location -Datastore $DataStore -DiskStorageFormat $DiskStorageFormat | Out-Null
Get-VM $Hostname | Get-NetworkAdapter | Set-NetworkAdapter -Portgroup $NetworkName -Confirm:$false | Out-Null
Set-VM -VM $Hostname -NumCpu $CPU -MemoryGB $Memory -Confirm:$false | Out-Null
Get-VM $Hostname | Get-HardDisk | Where-Object {$_.Name -eq "Hard Disk 1"} | Set-HardDisk -CapacityGB $DiskCapacity -Confirm:$false | Out-Null
Write-Host "Virtual machine $Hostname deployed. Powering on"
Start-VM -VM $Hostname | Out-Null
if (-not (Start-Customization $Hostname)) { break }
if (-not (Stop-Customizaton $Hostname)) { break }

foreach ($script in $scripts) {
    Invoke-VMScript -ScriptText $script.ScriptText -ScriptType $script.ScriptType -VM $Hostname -GuestCredential $VMLocalCredential | Out-Null
    if ($script.Reboot) {
        Restart-VM $Hostname
    }
}

### End of Script ##############################
Write-Host "Deployment of VM $Hostname finished"
