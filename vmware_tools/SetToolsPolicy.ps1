$spec = New-Object VMware.Vim.VirtualMachineConfigSpec
$spec.tools = New-Object VMware.Vim.ToolsConfigInfo
$spec.tools.toolsUpgradePolicy = "manual" # or "upgradeAtPowerCycle"
Foreach ($vmview in Get-View -ViewType VirtualMachine){
    $spec.changeVersion=$vmview.Config.changeversion
    $vmview.ReconfigVM_task($spec)
}
