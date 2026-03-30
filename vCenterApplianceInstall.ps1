# Deploy vCenter Server Appliance 8.x using vcsa-deploy CLI
#
# The vCSA 6 JSON template structure is not compatible with vCSA 7/8.
# The vCSA 8 installer ships with updated templates under:
#   <ISO>\vcsa-cli-installer\templates\install\
#
# This script uses the embedded_vCSA_on_ESXi.json template as its base
# and overwrites values before invoking the installer.
#
# Installer syntax changed in vCSA 7+:
#   vcsa-deploy.exe install --accept-eula --no-esx-ssl-verify <config.json>

$InstallerPath = "D:\vcsa-cli-installer\win32\vcsa-deploy.exe"
$TemplatePath  = "D:\vcsa-cli-installer\templates\install\embedded_vCSA_on_ESXi.json"
$OutputConfig  = "C:\Temp\vcsa-deploy-config.json"

# Prompt for all sensitive credentials — nothing hardcoded
$EsxiCred = Get-Credential -UserName "root"                      -Message "Enter ESXi host root credentials"
$RootCred = Get-Credential -UserName "root"                      -Message "Enter desired VCSA appliance root password"
$SsoCred  = Get-Credential -UserName "administrator@vsphere.local" -Message "Enter desired SSO administrator password"

# Load the stock template from the installer media
$json = Get-Content -Raw $TemplatePath | ConvertFrom-Json

# Appliance settings
$json.new_vcsa.appliance.name               = "Primary-vCSA8"
$json.new_vcsa.appliance.deployment_option  = "tiny"   # tiny/small/medium/large/xlarge
$json.new_vcsa.appliance.thin_disk_mode     = $true

# ESXi target host
$json.new_vcsa.esxi.hostname                = "10.144.99.11"
$json.new_vcsa.esxi.username                = $EsxiCred.UserName
$json.new_vcsa.esxi.password                = $EsxiCred.GetNetworkCredential().Password
$json.new_vcsa.esxi.deployment_network      = "VM Network"
$json.new_vcsa.esxi.datastore               = "ISCSI-SSD-900GB"

# Networking
$json.new_vcsa.network.ip_family            = "ipv4"
$json.new_vcsa.network.mode                 = "static"
$json.new_vcsa.network.system_name          = "10.144.99.19"   # FQDN or IP used as system name
$json.new_vcsa.network.ip                   = "10.144.99.19"
$json.new_vcsa.network.prefix               = "24"
$json.new_vcsa.network.gateway              = "10.144.99.1"
$json.new_vcsa.network.dns_servers          = @("10.144.99.5")

# OS / root account
$json.new_vcsa.os.password                  = $RootCred.GetNetworkCredential().Password
$json.new_vcsa.os.ntp_servers               = "pool.ntp.org"
$json.new_vcsa.os.ssh_enable                = $false

# SSO
$json.new_vcsa.sso.password                 = $SsoCred.GetNetworkCredential().Password
$json.new_vcsa.sso.domain_name              = "vsphere.local"
$json.new_vcsa.sso.site_name                = "Primary-Site"

# CEIP
$json.ceip.settings.ceip_enabled            = $false

$json | ConvertTo-Json -Depth 10 | Set-Content -Path $OutputConfig

# Run the installer
& $InstallerPath install --accept-eula --no-esx-ssl-verify $OutputConfig
