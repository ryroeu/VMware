Get-VM -Name * | Where-Object {$_.PowerState -eq "PoweredOff"} | Select-Object Name, PowerState, Notes | Export-Csv -Path .\VMsPoweredOff.csv -NoTypeInformation
