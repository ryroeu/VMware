Get-Datastore | Select-Object `
    @{N='Datastore';E={$script:p = [math]::Round(($_.CapacityGB - $_.FreeSpaceGB)/$_.CapacityGB*100,1)
        if ($p -lt 70){
            "#fg#$($_.Name)#fe#"
        }
        elseif ($p -lt 90){
            "#fy#$($_.Name)#fe#"
        }
        else {
            "#fr#$($_.Name)#fe#"
        }
    }
},
@{N='CapacityGB';E={[math]::Round($_.CapacityGB,1)}},
@{N='FreeSpaceGB';E={[math]::Round($_.FreeSpaceGB,1)}},
@{N='UsedPercent';E={$script:p}} | Export-Csv .\DataStoreReport.csv -NoTypeInformation