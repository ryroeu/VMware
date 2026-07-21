New-VIRole -Name 'New Custom Role' -Privilege (Get-VIPrivilege -PrivilegeGroup "Interaction","Provisioning")
