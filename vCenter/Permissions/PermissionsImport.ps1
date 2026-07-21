function Resolve-VIInventoryEntity {
    <#
    .SYNOPSIS
    Resolves a VIObject from inventory metadata saved in an export file.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$EntityId,

        [Parameter(Mandatory)]
        [string]$Name
    )

    try {
        return Get-View -Id $EntityId -ErrorAction Stop | Get-VIObjectByVIView -ErrorAction Stop
    }
    catch {
        $inventoryMatches = @(Get-Inventory -Name $Name -ErrorAction SilentlyContinue)

        if (-not $inventoryMatches) {
            return $null
        }

        $exactMatch = $inventoryMatches | Where-Object { $_.Id -eq $EntityId } | Select-Object -First 1
        if ($exactMatch) {
            return $exactMatch
        }

        if ($inventoryMatches.Count -eq 1) {
            return $inventoryMatches[0]
        }

        return $null
    }
}

function Import-Permission {
    <#
    .SYNOPSIS
    Imports permissions from a CSV file by using current PowerCLI permission cmdlets.
    .DESCRIPTION
    The function reads a CSV export and creates or updates permissions on vCenter
    inventory objects without calling the legacy AuthorizationManager view directly.
    .NOTES
    Source: Automating vSphere Administration
    .PARAMETER Filename
    The path of the CSV file to be imported.
    .EXAMPLE
    Import-Permissions -Filename "C:\Temp\Permissions.csv"
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Filename
    )

    process {
        $permissions = Import-Csv -Path $Filename

        foreach ($perm in $permissions) {
            $entity = Resolve-VIInventoryEntity -EntityId $perm.EntityId -Name $perm.Name
            if (-not $entity) {
                Write-Warning "Skipping [$($perm.Name)] because the inventory object could not be resolved."
                continue
            }

            $role = Get-VIRole -Name $perm.Role -ErrorAction SilentlyContinue
            if (-not $role) {
                Write-Warning "Skipping [$($perm.Name)] because role [$($perm.Role)] was not found."
                continue
            }

            $principal = $perm.Principal
            $isGroup = [System.Convert]::ToBoolean($perm.IsGroup)
            $propagate = [System.Convert]::ToBoolean($perm.Propagate)

            $existingPermission = Get-VIPermission -Entity $entity -ErrorAction Stop |
                Where-Object { $_.Principal -eq $principal } |
                Select-Object -First 1

            if ($existingPermission) {
                Write-Host "Updating permission on $($entity.Name) for $principal"
                Set-VIPermission -Permission $existingPermission -Role $role -Propagate:$propagate -Confirm:$false | Out-Null
                continue
            }

            Write-Host "Creating permission on $($entity.Name) for $principal"

            if ($isGroup) {
                New-VIPermission -Entity $entity -Role $role -GroupName $principal -Propagate:$propagate | Out-Null
            }
            else {
                New-VIPermission -Entity $entity -Role $role -UserName $principal -Propagate:$propagate | Out-Null
            }
        }
    }
}

# Example:
# Import-Permissions -Filename "C:\Temp\Permissions.csv"
