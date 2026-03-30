$VMs       = Import-Csv .\VMList.csv
$GuestCred = Get-Credential -Message "Enter guest VM credentials"

function Copy-File {
    foreach ($VM in $VMs) {
        Get-Item "C:\Directory\*" | Copy-VMGuestFile -Destination 'C:\Directory\' -VM $VM -LocalToGuest -GuestCredential $GuestCred -Confirm:$false
    }
}
