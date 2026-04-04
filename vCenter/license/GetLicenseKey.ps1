function Resolve-LicenseEntity {
    <#
    .SYNOPSIS
    Resolves a single inventory object by name for licensing operations.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$EntityName
    )

    $inventoryMatches = @(Get-Inventory -Name $EntityName -ErrorAction SilentlyContinue)

    if (-not $inventoryMatches) {
        throw "No inventory object named [$EntityName] was found."
    }

    if ($inventoryMatches.Count -gt 1) {
        throw "Multiple inventory objects named [$EntityName] were found. Use a unique name."
    }

    return $inventoryMatches[0]
}

function Get-LicenseKey {
    <#
    .SYNOPSIS
    Retrieves supported license association data from vCenter.
    .DESCRIPTION
    This function uses Get-LicenseDataManager, the supported PowerCLI licensing
    surface, to return either all entity-to-license associations or the
    associated/effective license data for a specific inventory object.
    .NOTES
    Source: Automating vSphere Administration
    .PARAMETER EntityName
    Optional inventory object name to inspect.
    .PARAMETER Effective
    When EntityName is specified, returns effective license data inherited from
    parent containers instead of only directly associated data.
    .EXAMPLE
    Get-LicenseKey
    .EXAMPLE
    Get-LicenseKey -EntityName "Cluster01"
    .EXAMPLE
    Get-LicenseKey -EntityName "Cluster01" -Effective
    #>
    [CmdletBinding()]
    param(
        [string]$EntityName,

        [switch]$Effective
    )

    process {
        $licenseDataManagers = @(Get-LicenseDataManager)

        foreach ($licenseDataManager in $licenseDataManagers) {
            if (-not $EntityName) {
                $licenseDataManager.QueryEntityLicenseData()
                continue
            }

            $entity = Resolve-LicenseEntity -EntityName $EntityName

            if ($Effective) {
                $licenseDataManager.QueryEffectiveLicenseData($entity.Uid)
            }
            else {
                $licenseDataManager.QueryAssociatedLicenseData($entity.Uid)
            }
        }
    }
}
