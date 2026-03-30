$DomainCred  = Get-Credential -Message "Enter domain join credentials for the customization spec"
$DomainUser  = $DomainCred.UserName
$DomainPass  = $DomainCred.GetNetworkCredential().Password

New-OSCustomizationSpec -Name "Win2022Spec" -FullName "Administrator" -OrgName "Organization Name" -Domain "domain.com" -DomainUsername $DomainUser -DomainPassword $DomainPass -Server VIServer -OSType Windows -TimeZone "Pacific Standard Time" -Type Persistent -ProductKey MSProductKey -NamingScheme Prefix -NamingPrefix ORG-LOC-WIN-
New-OSCustomizationNicMapping -OSCustomizationSpec "Win2022Spec" -IpMode UseStaticIP -IpAddress "10.10.10.100" -SubnetMask "255.255.255.0" -DefaultGateway "10.10.10.1" -AlternateGateway "10.10.10.2" -Dns "10.10.10.10" -Position 1
