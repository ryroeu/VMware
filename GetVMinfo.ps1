function Get-VMInformation {
    [CmdletBinding()]
    param(
        [Parameter(
            Position=0,
            ParameterSetName="NonPipeline"
        )]
        [Alias("VM")]
        [string[]]$Name,

        [Parameter(
            Position=1,
            ValueFromPipeline=$true,
            ValueFromPipelineByPropertyName=$true,
            ParameterSetName="Pipeline"
        )]
        [PSObject[]]$InputObject,

        [Parameter(ParameterSetName="NonPipeline")]
        [VMware.VimAutomation.ViCore.Types.V1.VIServer[]]$Server
    )

    begin {
        $defaultServers = Get-Variable -Name DefaultVIServers -Scope Global -ValueOnly -ErrorAction SilentlyContinue
        $defaultServer = Get-Variable -Name DefaultVIServer -Scope Global -ValueOnly -ErrorAction SilentlyContinue
        $connectedServers = @($defaultServers)
        if (-not $connectedServers -and $defaultServer) {
            $connectedServers = @($defaultServer)
        }

        if (-not $connectedServers) {
            Write-Error "Unable to continue. Please connect to one or more vCenter servers." -ErrorAction Stop
        }

        if ($PSBoundParameters.ContainsKey("Name")) {
            if ($PSBoundParameters.ContainsKey("Server")) {
                $InputObject = Get-VM -Name $Name -Server $Server
            } else {
                $InputObject = Get-VM -Name $Name
            }
        }

        $i = 1
        $count = $InputObject.Count
    }

    process {
        if (($null -eq $InputObject.VMHost) -and ($null -eq $InputObject.MemoryGB)) {
            Write-Error "Invalid data type. A virtual machine object was not found" -ErrorAction Continue
        }

        foreach ($object in $InputObject) {
            try {
                $vCenter = $object.Uid -replace ".+@"
                $vCenter = $vCenter -replace ":.+", ""
                [PSCustomObject]@{
                    Name        = $object.Name
                    Domain      = $object.ExtensionData.Guest.IpStack.DnsConfig.DomainName
                    IPAddress   = ($object.ExtensionData.Summary.Guest.IPAddress) -join ", "
                    GuestOS     = $object.ExtensionData.Config.GuestFullName
                    PowerState  = $object.PowerState
                    Datacenter  = $object.VMHost | Get-Datacenter | Select-Object -ExpandProperty Name
                    vCenter     = $vCenter
                    VMHost      = $object.VMHost
                    Cluster     = $object.VMHost | Get-Cluster | Select-Object -ExpandProperty Name
                    FolderName  = $object.Folder
                    Datastore   = ($object | Get-Datastore | Select-Object -ExpandProperty Name) -join ", "
                    NetworkName = ($object | Get-NetworkAdapter | Select-Object -ExpandProperty NetworkName) -join ", "
                    MacAddress  = ($object | Get-NetworkAdapter | Select-Object -ExpandProperty MacAddress) -join ", "
                    VMTools     = $object.ExtensionData.Guest.ToolsVersionStatus2
                }
            } catch {
                Write-Error $_.Exception.Message
            } finally {
                if ($PSBoundParameters.ContainsKey("Name")) {
                    $percentComplete = ($i / $count).ToString("P")
                    Write-Progress -Activity "Processing VM: $($object.Name)" -Status "$i/$count : $percentComplete Complete" -PercentComplete $percentComplete.Replace("%","")
                    $i++
                } else {
                    Write-Progress -Activity "Processing VM: $($object.Name)" -Status "Completed: $i"
                    $i++
                }
            }
        }
    }
}
# Get-VM | Get-VMInformation | Out-GridView
