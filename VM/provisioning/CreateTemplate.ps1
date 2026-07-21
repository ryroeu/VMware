$myVM = Get-VM -Name "NameOfBaseVM"
$drsCluster=Get-DatastoreCluster "MyDatastoreCluster"
New-Template -VM $myVM -Name "MyTemplate" -Server VIServer -Datastore $drsCluster -Location VIContainer -Confirm $false
