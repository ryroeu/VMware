[CmdletBinding()]
param(
    [string]$InstallerPath,
    [string]$TemplatePath,
    [string]$OutputPath,
    [hashtable]$Setting = @{},
    [switch]$NoSslCertificateVerification,
    [switch]$SkipDeployment
)

function Set-JsonValueByPath {
    <#
    .SYNOPSIS
    Updates a JSON object by using a slash-delimited property path.
    .DESCRIPTION
    The path format is /section/subsection/property. This avoids ambiguity with
    JSON keys that contain periods in their names.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [psobject]$InputObject,

        [Parameter(Mandatory)]
        [string]$Path,

        [AllowNull()]
        $Value
    )

    $segments = $Path.Trim("/") -split "/"
    if (-not $segments -or [string]::IsNullOrWhiteSpace($segments[0])) {
        throw "Invalid JSON path [$Path]. Use a slash-delimited path such as /new_vcsa/esxi/hostname."
    }

    $current = $InputObject

    for ($index = 0; $index -lt ($segments.Count - 1); $index++) {
        $segment = $segments[$index]
        $property = $current.PSObject.Properties[$segment]

        if (-not $property) {
            $child = [pscustomobject]@{}
            $current | Add-Member -MemberType NoteProperty -Name $segment -Value $child
            $current = $child
            continue
        }

        if ($null -eq $property.Value) {
            $property.Value = [pscustomobject]@{}
        }

        $current = $property.Value
    }

    $leafName = $segments[-1]
    $leafProperty = $current.PSObject.Properties[$leafName]

    if ($leafProperty) {
        $leafProperty.Value = $Value
    }
    else {
        $current | Add-Member -MemberType NoteProperty -Name $leafName -Value $Value
    }
}

function Invoke-VcsaCliInstall {
    <#
    .SYNOPSIS
    Deploys a modern vCenter Server Appliance by using the supported CLI installer.
    .DESCRIPTION
    This script starts from one of the JSON templates shipped with the vCenter
    ISO, applies override values, writes a generated configuration file, and
    optionally runs vcsa-deploy install.
    .PARAMETER InstallerPath
    Path to the current vcsa-deploy executable, for example
    D:\vcsa-cli-installer\win32\vcsa-deploy.exe.
    .PARAMETER TemplatePath
    Path to a current installer template, for example
    D:\vcsa-cli-installer\templates\install\embedded_vCSA_on_ESXi.json.
    .PARAMETER OutputPath
    Path where the generated JSON file should be written.
    .PARAMETER Setting
    Hashtable of slash-delimited JSON paths to values. Example:
    @{
        "/new_vcsa/esxi/hostname" = "esxi01.contoso.com"
        "/new_vcsa/esxi/username" = "root"
        "/new_vcsa/esxi/password" = "VMware123!"
        "/new_vcsa/appliance/name" = "vcsa01"
        "/new_vcsa/network/ip_family" = "ipv4"
        "/new_vcsa/network/mode" = "static"
        "/new_vcsa/network/ip" = "10.0.0.10"
        "/new_vcsa/network/prefix" = "24"
        "/new_vcsa/network/gateway" = "10.0.0.1"
        "/new_vcsa/network/dns_servers" = @("10.0.0.5", "10.0.0.6")
        "/new_vcsa/os/password" = "VMware123!"
        "/new_vcsa/os/ntp_servers" = "0.pool.ntp.org"
        "/new_vcsa/sso/password" = "VMware123!"
        "/new_vcsa/sso/domain_name" = "vsphere.local"
        "/new_vcsa/sso/site_name" = "Default-First-Site"
        "/ceip/settings/ceip_enabled" = $false
    }
    .PARAMETER NoSslCertificateVerification
    Adds the CLI flag that skips SSL verification during deployment.
    .PARAMETER SkipDeployment
    Generates the updated JSON file without running the installer.
    .EXAMPLE
    $settings = @{
        "/new_vcsa/esxi/hostname" = "esxi01.contoso.com"
        "/new_vcsa/esxi/username" = "root"
        "/new_vcsa/esxi/password" = "VMware123!"
        "/new_vcsa/appliance/name" = "vcsa01"
    }
    Invoke-VcsaCliInstall -InstallerPath "D:\vcsa-cli-installer\win32\vcsa-deploy.exe" `
        -TemplatePath "D:\vcsa-cli-installer\templates\install\embedded_vCSA_on_ESXi.json" `
        -OutputPath "C:\Temp\vcsa-install.generated.json" `
        -Setting $settings `
        -NoSslCertificateVerification
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)]
        [string]$InstallerPath,

        [Parameter(Mandatory)]
        [string]$TemplatePath,

        [string]$OutputPath,

        [hashtable]$Setting = @{},

        [switch]$NoSslCertificateVerification,

        [switch]$SkipDeployment
    )

    if (-not (Test-Path -Path $InstallerPath)) {
        throw "Installer path [$InstallerPath] was not found."
    }

    if (-not (Test-Path -Path $TemplatePath)) {
        throw "Template path [$TemplatePath] was not found."
    }

    if (-not $OutputPath) {
        $OutputPath = Join-Path -Path ([System.IO.Path]::GetDirectoryName($TemplatePath)) -ChildPath "vcsa-install.generated.json"
    }

    $config = Get-Content -Path $TemplatePath -Raw | ConvertFrom-Json -Depth 100

    foreach ($entry in ($Setting.GetEnumerator() | Sort-Object Key)) {
        Set-JsonValueByPath -InputObject $config -Path $entry.Key -Value $entry.Value
    }

    $outputDirectory = Split-Path -Path $OutputPath -Parent
    if ($outputDirectory -and -not (Test-Path -Path $outputDirectory)) {
        New-Item -ItemType Directory -Path $outputDirectory -Force | Out-Null
    }

    $config | ConvertTo-Json -Depth 100 | Set-Content -Path $OutputPath -Encoding utf8

    if ($SkipDeployment) {
        Get-Item -Path $OutputPath
        return
    }

    $arguments = @(
        "install"
        "--accept-eula"
    )

    if ($NoSslCertificateVerification) {
        $arguments += "--no-ssl-certificate-verification"
    }

    $arguments += $OutputPath

    if ($PSCmdlet.ShouldProcess($TemplatePath, "Deploy VCSA with generated config [$OutputPath]")) {
        & $InstallerPath @arguments

        if ($LASTEXITCODE -ne 0) {
            throw "vcsa-deploy failed with exit code $LASTEXITCODE."
        }
    }
}

if ($PSBoundParameters.Count -gt 0) {
    Invoke-VcsaCliInstall @PSBoundParameters
}
