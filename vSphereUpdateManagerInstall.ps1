# NOTE: The standalone vSphere Update Manager (VUM) Windows installer was discontinued
# with vSphere 7.0 (released 2020).
#
# Starting with vSphere 7.0, patch and update management is handled by
# vSphere Lifecycle Manager (vLCM), which is built directly into vCenter Server
# and requires no separate installation or database configuration.
#
# To access vSphere Lifecycle Manager in the vSphere Client:
#   Menu > Lifecycle Manager
#
# Key differences from standalone VUM:
#   - No external database required (embedded in vCenter)
#   - Supports image-based cluster management (desired state)
#   - Manages ESXi hosts, VMs, and vCenter itself
#
# Reference: https://docs.vmware.com/en/VMware-vSphere/8.0/vsphere-lifecycle-manager/

Write-Warning "Standalone vSphere Update Manager has not been available since vSphere 7.0 (2020)."
Write-Host    "Use vSphere Lifecycle Manager (vLCM), built into vCenter: Menu > Lifecycle Manager"
