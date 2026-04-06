Get-Datastore | Select-Object @{N="DataStoreName";E={$_.Name}},
    @{N="Percentage Free Space(%)";E={[math]::Round(($_.FreeSpaceGB)/($_.CapacityGB)*100,2)}} `
    | Where-Object {$_."Percentage(<20%)" -le 20} | Export-Csv .\DatastoreUsage.csv -NoTypeInformation