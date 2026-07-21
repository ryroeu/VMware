function Import-VMLocation {
<#
.SYNOPSIS
Imports the VMs back into their Blue Folders based on the data from a csv file.
.DESCRIPTION
The function will import VM locations from CSV File and add them to their correct Blue Folders.
.NOTES
Source:  Automating vSphere Administration
.PARAMETER DC
The Datacenter where the folders reside
.PARAMETER Filename
The path of the CSV file to use when importing
.EXAMPLE
​Import-VMLocation -DC "DC01" -Filename "C:\VMLocations.csv"
#>
    param(
        [String]$DC,
        [String]$Filename
    )
    Process {
        $Report = @()
        $Report = Import-Csv $filename | Sort-Object -Property Path
        foreach($vmpath in $Report){
            $key = @()
            $key = Split-Path $vmpath.Path | Split-Path -Leaf
            Move-VM (Get-Datacenter $dc | Get-VM $vmpath.Name) -Destination (Get-Datacenter $dc | Get-Folder $key)
        }
    }
}

Import-VMLocation "DC01" "C:\VMLocation.csv"
