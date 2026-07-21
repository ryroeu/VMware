$VM = Import-Csv -Path .\VMs.csv
Move-VM -VM $VM -Destination "*Decommission*"