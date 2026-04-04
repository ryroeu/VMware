[CmdletBinding()]
param(
    [string]$Server
)

function Get-VSphereClientUrl {
    <#
    .SYNOPSIS
    Returns the browser URL for the modern vSphere Client.
    .DESCRIPTION
    The legacy Windows vSphere Client has been retired. Current environments are
    managed through the browser-based vSphere Client at /ui.
    .PARAMETER Server
    The vCenter Server FQDN or IP address.
    .EXAMPLE
    Get-VSphereClientUrl -Server "vcsa01.contoso.com"
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Server
    )

    $normalizedServer = $Server -replace "^https?://", ""
    $normalizedServer = $normalizedServer.TrimEnd("/")

    [pscustomobject]@{
        Server = $normalizedServer
        Url = "https://$normalizedServer/ui"
        Note = "Use the browser-based vSphere Client. The legacy Windows client is no longer installed separately."
    }
}

if ($PSBoundParameters.Count -gt 0) {
    Get-VSphereClientUrl @PSBoundParameters
}
