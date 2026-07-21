function Get-ViSession {
    <#
    .SYNOPSIS
    Lists vCenter sessions.
    .DESCRIPTION
    Lists all connected vCenter sessions.
    .PARAMETER Server
    One or more vCenter Server connections. If omitted, uses all default server connections.
    .EXAMPLE
    PS C:\> Get-VISession
    .EXAMPLE
    PS C:\> Get-VISession | Where-Object { $_.IdleMinutes -gt 5 }
    #>
    [CmdletBinding()]
    param(
        [VMware.VimAutomation.ViCore.Types.V1.VIServer[]]$Server
    )

    if (-not $PSBoundParameters.ContainsKey("Server")) {
        $defaultServers = Get-Variable -Name DefaultVIServers -Scope Global -ValueOnly -ErrorAction SilentlyContinue
        $defaultServer = Get-Variable -Name DefaultVIServer -Scope Global -ValueOnly -ErrorAction SilentlyContinue
        $Server = @($defaultServers)
        if (-not $Server -and $defaultServer) {
            $Server = @($defaultServer)
        }
    }

    if (-not $Server) {
        Write-Error "Unable to continue. Please connect to one or more vCenter servers." -ErrorAction Stop
    }

    foreach ($VIServer in $Server) {
        $sessionMgr = Get-View -Id $VIServer.ExtensionData.Client.ServiceContent.SessionManager -Server $VIServer

        foreach ($sessionInfo in $sessionMgr.SessionList) {
            [pscustomobject]@{
                Server         = $VIServer.Name
                Key            = $sessionInfo.Key
                UserName       = $sessionInfo.UserName
                FullName       = $sessionInfo.FullName
                LoginTime      = $sessionInfo.LoginTime.ToLocalTime()
                LastActiveTime = $sessionInfo.LastActiveTime.ToLocalTime()
                Status         = if ($sessionInfo.Key -eq $sessionMgr.CurrentSession.Key) { "Current Session" } else { "Idle" }
                IdleMinutes    = [Math]::Round(((Get-Date) - $sessionInfo.LastActiveTime.ToLocalTime()).TotalMinutes)
            }
        }
    }
}
