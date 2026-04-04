[CmdletBinding()]
param(
    [string]$InstallerPath,
    [string]$TemplatePath,
    [string]$OutputPath,
    [hashtable]$Setting = @{},
    [switch]$NoSslCertificateVerification,
    [switch]$SkipDeployment
)

<#
.SYNOPSIS
Compatibility wrapper for modern vCenter appliance deployment.
.DESCRIPTION
vCenter Server for Windows was removed in vSphere 7.0. This wrapper keeps the
legacy filename but forwards to the current VCSA CLI deployment workflow.
#>

$vcsaScript = Join-Path -Path $PSScriptRoot -ChildPath "vCenterApplianceInstall.ps1"

if (-not (Test-Path -Path $vcsaScript)) {
    throw "Expected appliance installer wrapper [$vcsaScript] was not found."
}

& $vcsaScript @PSBoundParameters
