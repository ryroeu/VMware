Function Get-VMInformation {
    [CmdletBinding()]
    param(
        [Parameter(
            Position=0,
            ParameterSetName="NonPipeline"
        )]

        [Alias("VM")]
        [string[]]  $Name,

        [Parameter(
            Position=1,
            ValueFromPipeline=$true,
            ValueFromPipelineByPropertyName=$true,
            ParameterSetName="Pipeline"
            )]
        [PSObject[]]  $InputObject
    )

    BEGIN {
        if (-not $Global:DefaultVIServer) {
            Write-Error "Unable to continue.  Please connect to a vCenter Server." -ErrorAction Stop
        }

        #Verifying the object is a VM
        if ($PSBoundParameters.ContainsKey("Name")) {
            $InputObject = Get-VM $Name
        }

        $i = 1
        $Count = $InputObject.Count
    }

    PROCESS {
        if (($null -eq $InputObject.VMHost) -and ($null -eq $InputObject.MemoryGB)) {
            Write-Error "Invalid data type. A virtual machine object was not found" -ErrorAction:Continue
        }

        foreach ($Object in $InputObject) {
            try {
                $vCenter = $Object.Uid -replace ".+@"; $vCenter = $vCenter -replace ":.+"
                [PSCustomObject]@{
                    Name        = $Object.Name
                    Domain      = $Object.ExtensionData.Guest.IpStack.DnsConfig.DomainName
                    IPAddress   = ($Object.ExtensionData.Summary.Guest.IPAddress) -join ', '
                    GuestOS     = $Object.ExtensionData.Config.GuestFullName
                    PowerState  = $Object.PowerState
                    Datacenter  = $Object.VMHost | Get-Datacenter | Select-Object -ExpandProperty Name
                    vCenter     = $vCenter
                    VMHost      = $Object.VMhost
                    Cluster     = $Object.VMhost | Get-Cluster | Select-Object -ExpandProperty Name
                    FolderName  = $Object.Folder
                    Datastore   = ($Object | Get-Datastore | Select-Object -ExpandProperty Name) -join ', '
                    NetworkName = ($Object | Get-NetworkAdapter | Select-Object -ExpandProperty NetworkName) -join ', '
                    MacAddress  = ($Object | Get-NetworkAdapter | Select-Object -ExpandProperty MacAddress) -join ', '
                    VMTools     = $Object.ExtensionData.Guest.ToolsVersionStatus2
                }

            } catch {
                Write-Error $_.Exception.Message

            } finally {
                if ($PSBoundParameters.ContainsKey("Name")) {
                    $PercentComplete = ($i/$Count).ToString("P")
                    Write-Progress -Activity "Processing VM: $($Object.Name)" -Status "$i/$count : $PercentComplete Complete" -PercentComplete $PercentComplete.Replace("%","")
                    $i++
                } else {
                    Write-Progress -Activity "Processing VM: $($Object.Name)" -Status "Completed: $i"
                    $i++
                }
            }
        }
    }
    END {}
}
#Get-VM | Get-VMInformation | Out-GridView