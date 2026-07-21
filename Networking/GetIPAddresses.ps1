Get-VM -Name * | Select-Object Name, @{N="IP Address";E={@($_.guest.IPAddress[0])}} | Export-Csv .\IP_Addresses.csv -NoTypeInformation
