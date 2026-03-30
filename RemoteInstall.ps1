$VMs       = Import-Csv .\VMList.csv
$GuestCred = Get-Credential -Message "Enter guest VM credentials"

# Copy installation package to destination VMs
function Copy-File {
    foreach ($VM in $VMs) {
        Get-Item "C:\Directory\*" | Copy-VMGuestFile -Destination 'C:\Directory\' -VM $VM -LocalToGuest -GuestCredential $GuestCred -Confirm:$false
    }
}

# Run remote installation on each VM
function Get-Installation {
    foreach ($VM in $VMs) {
        Invoke-VMScript -VM $VM -ScriptType Powershell -ScriptText "Start-Process -FilePath 'C:\Directory\NameofPackage.msi' -ArgumentList '/Silent' -Wait" -GuestCredential $GuestCred -Confirm:$false
    }
}

# Execute
Copy-File | Wait-Job
Get-Installation | Wait-Job
