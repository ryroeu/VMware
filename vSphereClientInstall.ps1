# NOTE: The vSphere C# Client (VMware-viclient.exe) was deprecated with vSphere 6.5
# and removed entirely with vSphere 7.0 (released 2020).
#
# vSphere 8 uses exclusively the HTML5-based vSphere Client, which is built into
# vCenter Server and requires no client-side installation.
#
# To access the vSphere Client, open a browser and navigate to:
#   https://<vCenter-FQDN-or-IP>/ui
#
# Reference: https://docs.vmware.com/en/VMware-vSphere/8.0/vsphere-vcenter-installation/

Write-Warning "The vSphere C# Client has not been available since vSphere 7.0 (2020)."
Write-Host    "Access the HTML5 vSphere Client in a browser at: https://<vCenter>/ui"
