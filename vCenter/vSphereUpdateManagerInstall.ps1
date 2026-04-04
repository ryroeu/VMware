[CmdletBinding()]
param(
    [string]$DownloadToken
)

function Get-LifecycleManagerDepotUrl {
    <#
    .SYNOPSIS
    Builds Broadcom depot URLs for vSphere Lifecycle Manager.
    .DESCRIPTION
    Standalone VMware Update Manager installers are retired. Current vSphere
    releases use the built-in Lifecycle Manager service in the vSphere Client.
    If you patch from Broadcom-hosted depots, this helper returns the standard
    depot URLs for a download token.
    .PARAMETER DownloadToken
    The Broadcom authenticated download token.
    .EXAMPLE
    Get-LifecycleManagerDepotUrl -DownloadToken "token-value"
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$DownloadToken
    )

    @(
        [pscustomobject]@{
            Component = "Main"
            Url = "https://dl.broadcom.com/$DownloadToken/PROD/COMP/ESX_HOST/main/vmw-depot-index.xml"
        }
        [pscustomobject]@{
            Component = "Addon"
            Url = "https://dl.broadcom.com/$DownloadToken/PROD/COMP/ESX_HOST/addon-main/vmw-depot-index.xml"
        }
        [pscustomobject]@{
            Component = "IOVP"
            Url = "https://dl.broadcom.com/$DownloadToken/PROD/COMP/ESX_HOST/iovp-main/vmw-depot-index.xml"
        }
    )
}

function Get-LifecycleManagerGuidance {
    <#
    .SYNOPSIS
    Returns the modern replacement guidance for legacy Update Manager installs.
    .EXAMPLE
    Get-LifecycleManagerGuidance
    #>
    [CmdletBinding()]
    param(
        [string]$DownloadToken
    )

    $guidance = @(
        [pscustomobject]@{
            Step = 1
            Detail = "There is no standalone Update Manager installer in current vSphere releases."
        }
        [pscustomobject]@{
            Step = 2
            Detail = "Use the built-in Lifecycle Manager service from the vSphere Client."
        }
        [pscustomobject]@{
            Step = 3
            Detail = "Open the vSphere Client and navigate to Lifecycle Manager to configure depots, images, and remediation."
        }
    )

    if ($DownloadToken) {
        $guidance + (Get-LifecycleManagerDepotUrl -DownloadToken $DownloadToken)
    }
    else {
        $guidance
    }
}

Get-LifecycleManagerGuidance @PSBoundParameters
