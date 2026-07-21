# Need CSV file with Name and Notes column populated with desired info
Import-Csv .\VMList.csv | ForEach-Object {Set-VM $_.Name -Notes $_.Notes -Confirm:$false}
