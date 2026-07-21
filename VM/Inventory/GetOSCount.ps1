function Get-VMOSList {
    [CmdletBinding()]
    param($vCenter)

    [array]$osNameObject = $null
    [array]$guestOSList = @()
    $vmHosts = Get-VMHost
    $i = 0

    foreach ($h in $vmHosts) {
        Write-Progress -Activity "Going through each host in $vCenter..." -Status "Current Host: $h" -PercentComplete ($i / $vmHosts.Count * 100)
        $osName = ($h | Get-VM | Get-View).Summary.Config.GuestFullName
        [array]$guestOSList += $osName
        Write-Verbose "Found OS: $osName"
        $i++
    }

    $names = $guestOSList | Select-Object -Unique
    $i = 0
    foreach ($n in $names) {
        Write-Progress -Activity "Going through VM OS Types in $vCenter..." -Status "Current Name: $n" -PercentComplete ($i / $names.Count * 100)
        $vmTotal = ($guestOSList | Where-Object {$_ -eq $n}).Count
        $osNameProperty = @{'Name'=$n}
        $osNameProperty += @{'Total VMs'=$vmTotal}
        $osNameProperty += @{'vCenter'=$vCenter}
        $osnO = New-Object PSObject -Property $osNameProperty
        $osNameObject += $osnO
        $i++
    }

    return $osNameObject
}

$OutputPath = Join-Path $PSScriptRoot "OSCount.csv"
Get-VMOSList | Export-Csv -Path $OutputPath -NoTypeInformation -UseCulture
