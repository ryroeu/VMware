$VMs = Import-Csv .\VMList.csv
$GuestCred = Get-Credential -Message "Enter guest VM credentials"
$PackageSourcePath = Join-Path $PSScriptRoot "Directory"
$GuestDestinationPath = "C:\Directory\"
$InstallerPath = "C:\Directory\NameofPackage.msi"

# Copy installation package to destination VMs
function Copy-File {
    if (-not (Test-Path -LiteralPath $PackageSourcePath)) {
        throw "Package source path '$PackageSourcePath' does not exist."
    }

    foreach ($VM in $VMs) {
        Get-ChildItem -Path $PackageSourcePath -Force | Copy-VMGuestFile -Destination $GuestDestinationPath -VM $VM -LocalToGuest -GuestCredential $GuestCred -Confirm:$false
    }
}

# Run remote installation on each VM
function Get-Installation {
    foreach ($VM in $VMs) {
        Invoke-VMScript -VM $VM -ScriptType PowerShell -ScriptText "Start-Process -FilePath '$InstallerPath' -ArgumentList '/Silent' -Wait" -GuestCredential $GuestCred -Confirm:$false
    }
}

# Execute
Copy-File
Get-Installation
