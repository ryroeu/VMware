function Set-LicenseKey {
    <#
    .SYNOPSIS
    Associates and applies a vSphere license key to a host.
    .DESCRIPTION
    This function uses the current LicenseDataManager API exposed by PowerCLI to
    associate a license key with a host and apply it immediately.
    .NOTES
    Source: Automating vSphere Administration
    .PARAMETER LicKey
    The license key to associate with the host.
    .PARAMETER VMHost
    The ESXi host that should receive the license key.
    .PARAMETER TypeId
    The VMware license type identifier. Defaults to vmware-vsphere.
    .PARAMETER Name
    Retained for backward compatibility. The current licensing API does not use
    a friendly name during assignment.
    .EXAMPLE
    Set-LicenseKey -LicKey "AAAAA-BBBBB-CCCCC-DDDDD-EEEEE" -VMHost "esxhost01.contoso.com"
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)]
        [string]$VMHost,

        [Parameter(Mandatory)]
        [string]$LicKey,

        [string]$TypeId = "vmware-vsphere",

        [string]$Name
    )

    process {
        $vmHostObject = Get-VMHost -Name $VMHost -ErrorAction Stop
        $licenseDataManager = Get-LicenseDataManager

        $licenseData = New-Object Vmware.VimAutomation.License.Types.LicenseData
        $licenseKeyEntry = New-Object Vmware.VimAutomation.License.Types.LicenseKeyEntry
        $licenseKeyEntry.TypeId = $TypeId
        $licenseKeyEntry.LicenseKey = $LicKey
        $licenseData.LicenseKeys += $licenseKeyEntry

        if ($Name) {
            Write-Verbose "Ignoring legacy friendly name [$Name] because the current LicenseDataManager API does not persist it during assignment."
        }

        if ($PSCmdlet.ShouldProcess($vmHostObject.Name, "Associate and apply license key")) {
            $licenseDataManager.UpdateAssociatedLicenseData($vmHostObject.Uid, $licenseData)
            $licenseDataManager.ApplyAssociatedLicenseData($vmHostObject.Uid)
        }

        Get-VMHost -Name $vmHostObject.Name | Select-Object Name, LicenseKey, Uid
    }
}

# Example:
# Set-LicenseKey -LicKey "AAAAA-BBBBB-CCCCC-DDDDD-EEEEE" -VMHost "esxhost01.contoso.com"
