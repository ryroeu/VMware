Function Get-ViIdleSession{
    <#
    .SYNOPSIS
    Get Idle sessions from vcenters
    .DESCRIPTION
    This script gets all the sessions in the last 8 hours inactive
    .NOTES
    Authors:  Guilherme Alves Stela
                Mauro Bonder
    .PARAMETER vclist
    This parameter specifies the connection(s) to any vcenters wanted.

    .PARAMETER excluded
    This parameter specifies the file container of the list of users who will be excluded from the output list of inactive sessions.
    .EXAMPLE
    $vcs = Connect-viserver -Server "myserver" -AllLinked:$true
    $usersToExclude = Get-content (myfile.txt)
    Get-viIdleSessions -vclist $vcs -excluded $usersToExclude

    This command retrieves information about all users logged on the servers specified in the variable $vcs
    #>
    param($vclist,$excluded)
    $report=@()
    foreach($vc in $vclist){
        $sessMgr = Get-View SessionManager -Server $vc
        #Loop under SessionManager from vcenter
        foreach($sess in $sessMgr){
            #Get All Sessions
            foreach($subsess in $sess.Sessionlist){
                #if last active time less than 8 hours, add to oldsessions list
                if(((($subsess.LastActiveTime).AddHours(8)) -lt (Get-date)) -and ($excluded -notcontains $subSess.Username)){
                    $row ="" | Select-Object Username,FullName,TimeStamp,Server,LoginTime,LastActiveTime,Key
                    $row.Username = $subsess.UserName
                    $row.FullName = $subsess.FullName
                    $row.TimeStamp = Get-Date
                    $row.Server = $vc.Name
                    $row.LoginTime = $subsess.LoginTime
                    $row.LastActiveTime = $subsess.LastActiveTime
                    $row.Key = $subsess.key
                    $report += $row
                }
            }
        }
    }
    return $report
}
<# Get Example:
$report = Get-ViIdleSessions -vclist (connect-viserver "myserver") -excluded (Get-Content "./excluded-users.txt")
#>

# Disconnect Idle Sessions #
Function Disconnect-ViIdleSession {
    param($list,$vcs)
    $list | ForEach-Object {
        $key = $_.Key
        $server = $_.Server
        $vcs | ForEach-Object {
            if($_.Name -eq $server) {
                $SessionMgr = Get-View $_.ExtensionData.Client.ServiceContent.SessionManager
                $SessionMgr.TerminateSession($key)
            }
        }
    }
}
<# Disconnect Example:
Disconnect-ViIdleSessions -list $Allreport -vcs $conns
#>