### TAKE A NEW SNAPSHOT OF VM ###
# The original function was named New-Snapshot, which silently shadowed the PowerCLI
# cmdlet of the same name, causing the function to call itself recursively instead of
# creating a snapshot. Renamed to Invoke-NewSnapshot to avoid the collision.
# Also fixed: -Memory $false -> -Memory:$false, -Confirm $false -> -Confirm:$false,
# and $ComputerName.SNAPSHOT -> "$($VM.Name).SNAPSHOT"

$VMs = Import-Csv .\VMList.csv

function Invoke-NewSnapshot {
    foreach ($VM in $VMs) {
        New-Snapshot -VM $VM.Name -Name "$($VM.Name).SNAPSHOT" -Description "Snapshot" -Memory:$false -Quiesce:$true -Confirm:$false
    }
}
Invoke-NewSnapshot
