# NOTE: The Windows-based vCenter Server installer (VMware-vCenter-Server.msi) was
# discontinued after vCenter Server 6.7 (released 2018).
#
# Starting with vCenter Server 7.0, vCenter is only available as the
# vCenter Server Appliance (VCSA) — a Linux-based virtual appliance deployed
# via the vcsa-deploy CLI or the GUI installer included on the vCSA ISO.
#
# Use vCenterApplianceInstall.ps1 to deploy vCenter Server 8.x.
#
# Reference: https://docs.vmware.com/en/VMware-vSphere/8.0/vsphere-vcenter-installation/

Write-Warning "The Windows-based vCenter installer has not been available since vCenter 7.0 (2020)."
Write-Host    "Deploy vCenter Server Appliance (VCSA) using vCenterApplianceInstall.ps1"
