function Export-PermissionsToCSV {
    <#
    .SYNOPSIS
    Exports all Permissions to CSV file
    .DESCRIPTION
    The function will export all permissions to a CSV based file for later import
    .NOTES
    ​ Source:  Automating vSphere Administration
    .PARAMETER Filename
    The path of the CSV file to be created
    .EXAMPLE
    Export-PermissionsToCSV -Filename "C:\Temp\Permissions.csv"
    #>
    param(
        [String]$Filename
    )
    Process {
        $folderperms = Get-Datacenter | Get-Folder | Get-VIPermission
        $vmperms = Get-Datacenter | Get-VM | Get-VIPermission
        $permissions = Get-Datacenter | Get-VIpermission
        $report = @()
        foreach($perm in $permissions){
            $row = "" | Select-Object EntityId, Name, Role, Principal, IsGroup, Propagate
            $row.EntityId = $perm.EntityId
            $Foldername = (Get-View -Id $perm.EntityId –Property Name).Name
            $row.Name = $foldername
            $row.Principal = $perm.Principal
            $row.Role = $perm.Role
            $row.IsGroup = $perm.IsGroup
            $row.Propagate = $perm.Propagate
            $report += $row
        }
        foreach($perm in $folderperms){
            $row = "" | Select-Object EntityId, Name, Role, Principal, IsGroup, Propagate
            $row.EntityId = $perm.EntityId
            $Foldername = (Get-View -Id $perm.EntityId –Property Name).Name
            $row.Name = $foldername
    ​        $row.Principal = $perm.Principal
            $row.Role = $perm.Role
            $row.IsGroup = $perm.IsGroup
            $row.Propagate = $perm.Propagate
            $report += $row
        }
        foreach($perm in $vmperms){
            $row = "" | Select-Object EntityId, Name, Role, Principal, IsGroup, Propagate
            $row.EntityId = $perm.EntityId
            $Foldername = (Get-View -Id $perm.EntityId –Property Name).Name
            $row.Name = $foldername
            $row.Principal = $perm.Principal
            $row.Role = $perm.Role
            $row.IsGroup = $perm.IsGroup
            $row.Propagate = $perm.Propagate
            $report += $row
        }
        $report | Export-Csv $Filename -NoTypeInformation
    }
}

Export-PermissionsToCSV -Filename "C:\Temp\Permissions.csv"
