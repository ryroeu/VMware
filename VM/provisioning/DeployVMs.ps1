$VMs = Import-CSV .\NewVMs.csv
foreach ($VM in $VMs){
    #Assign Variables
    $Template = Get-Template -Name $VM.Template
    $Cluster = $VM.Cluster
    $Datastore = Get-Datastore -Name $VM.Datastore
    $Custom = Get-OSCustomizationSpec -Name $VM.Customization
    $vCPU = $VM.vCPU
    $Memory = $VM.Memory
    $Network = $VM.Network
    $Location = $VM.Location
    $VMName = $VM.Name
    #Where the VM gets built
    New-VM -Name $VMName -Template $Template -ResourcePool (Get-Cluster $Cluster | Get-ResourcePool) -Location $Location -StorageFormat Thin -Datastore $Datastore -OSCustomizationSpec $Custom
    Start-Sleep -Seconds 10
    #Where the vCPU, memory, and network gets set
    $NewVM = Get-VM -Name $VMName
    $NewVM | Set-VM -MemoryGB $Memory -NumCpu $vCPU -Confirm:$false
    $NewVM | Get-NetworkAdapter | Set-NetworkAdapter -NetworkName $Network -Confirm:$false
}
