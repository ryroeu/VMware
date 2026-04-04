function Set-DPM {
    <#
    .SYNOPSIS
    Enables Distributed Power Management on a cluster
    .DESCRIPTION
    This function will allow you to configure
    DPM on an existing vCenter Server cluster
    .NOTES
    Source:  Automating vSphere Administration
    .PARAMETER Cluster
    The cluster on which to set DPM configuration
    .PARAMETER Behavior
    DPM Behavior, this can be set to "off", "manual" or "Automated", by default it is "off"
    .EXAMPLE
    Set-DPM -Cluster "Cluster01" -Behavior "Automated"
    #>
    param(
    [String]$Cluster,
    [String]$Behavior
    )

    Process {
        switch ($Behavior) {
            "Off" {
                $DPMBehavior = "Automated"
                $Enabled = $false
            }
            "Automated" {
                $DPMBehavior = "Automated"
                $Enabled = $true
            }
            "Manual" {
                $DPMBehavior = "Manual"
                $Enabled = $true
            }
            default {
                $DPMBehavior = "Automated"
                $Enabled = $false
            }
        }
        $clus = Get-Cluster $Cluster | Get-View –Property Name
        $spec = New-Object VMware.Vim.ClusterConfigSpecEx
        $spec.dpmConfig = New-Object VMware.Vim.ClusterDpmConfigInfo
        $spec.DpmConfig.DefaultDpmBehavior = $DPMBehavior
        $spec.DpmConfig.Enabled = $Enabled
        $clus.ReconfigureComputeResource_Task($spec, $true)
        $clus.UpdateViewData("ConfigurationEx")
        New-Object -TypeName PSObject -Property @{
            Cluster = $clus.Name; 
            DPMEnabled = $clus.ConfigurationEx.DpmConfigInfo.Enabled; 
            DefaultDpmBehavior = $clus.ConfigurationEx.DpmConfigInfo.DefaultDpmBehavior
        }
    }
}

Set-DPM -Cluster "Cluster01" -Behavior "Automated"
