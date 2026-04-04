function Import-Folders {
  <#
  .SYNOPSIS
  Imports a csv file of folders into vCenter Server and creates them automatically.
  .DESCRIPTION
  The function will import folders from CSV file and create them in vCenter Server.
  .NOTES
  ​Source:  Automating vSphere Administration
  .PARAMETER FolderType
  The type of folder to create
  .PARAMETER DC
  The Datacenter to create the folder structure
  .PARAMETER Filename
  The path of the CSV file to use when importing
  .EXAMPLE
  Import-Folders -FolderType "Blue" -DC "DC01" -Filename "C:\BlueFolders.csv"
  .EXAMPLE
  Import-Folders -FolderType "Yellow" -DC "Datacenter" -Filename "C:\YellowFolders.csv"
  #>
  param(
    [String]$FolderType,
    [String]$DC,
    [String]$Filename
  )
  process{
    $vmfolder = Import-Csv $filename | Sort-Object -Property Path
    If ($FolderType -eq "Yellow") {
      $type = "host"
    } 
    Else {
      $type = "vm"
    }
    foreach($folder in $VMfolder){
      $key = @()
      $key = ($folder.Path -split "\\")[-2]
      if ($key -eq "vm") {
        Get-Datacenter $dc | Get-Folder $type | New-Folder -Name $folder.Name
      } 
      Else {
        Get-Datacenter $dc | Get-Folder $type | Get-Folder $key | New-Folder -Name $folder.Name
      }
    }
  }
}

Import-Folders -FolderType "blue" -DC "DC01" -Filename "C:\BlueFolders.csv"
