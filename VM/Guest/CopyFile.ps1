$VMs = Import-Csv .\VMList.csv
$GuestCred = Get-Credential -Message "Enter guest VM credentials"
$PackageSourcePath = Join-Path $PSScriptRoot "Directory"
$GuestDestinationPath = "C:\Directory\"

function Copy-File {
    if (-not (Test-Path -LiteralPath $PackageSourcePath)) {
        throw "Package source path '$PackageSourcePath' does not exist."
    }

    foreach ($VM in $VMs) {
        Get-ChildItem -Path $PackageSourcePath -Force | Copy-VMGuestFile -Destination $GuestDestinationPath -VM $VM -LocalToGuest -GuestCredential $GuestCred -Confirm:$false
    }
}
