# Original script had a logic bug: it looped over powered-on VMs but called
# Get-VMHostNetworkAdapter -VMKernel (a host-level cmdlet) without using $VM,
# so the loop produced duplicate host adapter rows instead of per-VM network info.
#
# Fixed to collect VM network adapter details per powered-on VM.
# Requires VMware Tools running in the guest for IP address data.

Get-VM -Name * | Where-Object {$_.PowerState -eq "PoweredOn"} | ForEach-Object {
    $vm = $_
    $vm | Get-NetworkAdapter | Select-Object `
        @{N='VMName';     E={$vm.Name}},
        Name,
        Type,
        MacAddress,
        NetworkName,
        @{N='IPAddress';  E={($vm.Guest.IPAddress -join '; ')}}
} | Export-Csv .\NetworkInfo.csv -NoTypeInformation
