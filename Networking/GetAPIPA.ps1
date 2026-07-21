### Export VMs that have APIPA Addresses to CSV ###
Get-View -ViewType VirtualMachine `
         -Property Name, Guest. IPAddress `
         -Filter @{"Guest.IpAddress"="169.254.*"} | Select-Object Name, @{N="IP";E={@($_.Guest.IPAddress)}} `
| Export-Csv .\APIPAIPAddresses.csv -NoTypeInformation