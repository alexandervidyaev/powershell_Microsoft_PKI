#prerequisites
$RootHostname = "root"
$IpRootCA = "10.7.160.50"
$CACommonName = "RootCA"
$UsernameRoot = "Administrator"
$PasswordRoot = "P@ssw0rd"
$SubCADNSName = "dc-01.test.local"
$IpSubCA = "10.7.160.51"
$UsernameSubCA = "TEST\Administrator"
$PasswordSubCA = "P@ssw0rd1"
$SubCACommonName = "dc-01-subCA"
$SubCADistinguishedNameSuffix = "DC=test,DC=local"


$PasswordRootConverted = ConvertTo-SecureString $PasswordRoot -AsPlainText -Force
$CredentialsRoot = New-Object System.Management.Automation.PSCredential($UsernameRoot, $PasswordRootConverted)
$PasswordSubCAConverted = ConvertTo-SecureString $PasswordSubCA -AsPlainText -Force
$CredentialsSubCA = New-Object System.Management.Automation.PSCredential($UsernameSubCA, $PasswordSubCAConverted)
Install-WindowsFeature AD-Certificate, ADCS-Cert-Authority -IncludeManagementTools
Install-WindowsFeature ADCS-Web-Enrollment -IncludeManagementTools
Install-AdcsCertificationAuthority -CACommonName $CACommonName `
    -CADistinguishedNameSuffix "CN=$CACommonName" `
    -CAType StandaloneRootCA `
    -CryptoProviderName "RSA#Microsoft Software Key Storage Provider" `
    -KeyLength 2048 `
    -HashAlgorithmName SHA256 `
    -ValidityPeriod "years" `
    -ValidityPeriodUnits 20 `
    -DatabaseDirectory $(Join-Path $env:SystemRoot "System32\CertLog") -Confirm:$False
Install-AdcsWebEnrollment -Confirm:$False
certutil -setreg CA\CRLPublicationURLs "65:C:\Windows\system32\CertSrv\CertEnroll\%3%8%9.crl\n14:http://$SubCADNSName/CertEnroll/%3%8%9.crl"
certutil -setreg CA\CACertPublicationURLs "1:C:\Windows\system32\CertSrv\CertEnroll\%1_%3%4.crt\n2:http://$SubCADNSName/CertEnroll/%1_%3%4.crt"
certutil -setreg CA\ValidityPeriodUnits 15
certutil -setreg CA\ValidityPeriod "Years"
net stop certsvc 
net start certsvc
Copy-Item "C:\Windows\System32\certsrv\CertEnroll\root_$CACommonName.crt" -Destination "C:\"
Copy-Item "C:\Windows\System32\certsrv\CertEnroll\$CACommonName.crl" -Destination "C:\"
set-item wsman:\localhost\client\trustedhosts -Concatenate -value $IpSubCA -force

Invoke-Command -ComputerName $IpSubCA -ScriptBlock {
Install-WindowsFeature AD-Certificate, ADCS-Cert-Authority -IncludeManagementTools
Install-WindowsFeature ADCS-Web-Enrollment -IncludeManagementTools
Install-AdcsCertificationAuthority -CACommonName $using:SubCACommonName `
    -CADistinguishedNameSuffix $using:SubCADistinguishedNameSuffix `
    -CAType EnterpriseSubordinateCa `
    -CryptoProviderName "RSA#Microsoft Software Key Storage Provider" `
    -KeyLength 2048 `
    -HashAlgorithmName SHA256 -Confirm:$False	
Install-AdcsWebEnrollment -Confirm:$False 
$SourceReqSubCA = "C:\*.req"
$DestinationRoot   = "\\$Using:IpRootCA\CertEnroll"
New-PSDrive -Name J -PSProvider FileSystem -Root $DestinationRoot  -Credential $Using:CredentialsRoot -Persist
Copy-Item -Path $SourceReqSubCA -Destination "J:\$using:SubCACommonName.req"
} -credential $CredentialsSubCA

certreq -submit -config $RootHostname\$CACommonName "C:\Windows\System32\certsrv\CertEnroll\$SubCACommonName.req"
certutil -resubmit 2
certreq -config $RootHostname\$CACommonName -retrieve 2  "C:\cert.crt"

$SourceCerts = "C:\*.crt"
$SourceCRL = "C:\$CACommonName.crl"
$DestSub   = "\\$IpSubCA\CertEnroll"
New-PSDrive -Name J -PSProvider FileSystem -Root $DestSub -Credential $CredentialsSubCA -Persist
Copy-Item -Path $SourceCerts -Destination "J:\"
Copy-Item -Path $SourceCRL -Destination "J:\"

Invoke-Command -ComputerName $IpSubCA -ScriptBlock {
$TrustedRootPath = 'C:\Windows\System32\certsrv\CertEnroll\$RootHostname_$CACommonName.crt'
Import-Certificate -FilePath $TrustedRootPath -CertStoreLocation Cert:\LocalMachine\Root
certutil -silent -installcert C:\Windows\System32\certsrv\CertEnroll\cert.crt
C:\Windows\System32\inetsrv\appcmd.exe set config "Default Web Site" -section:system.webServer/directoryBrowse /enabled:"True" /showFlags:"Date, Time, Size, Extension"
certutil -setreg CA\CRLPublicationURLs "65:C:\Windows\system32\CertSrv\CertEnroll\%3%8%9.crl\n14:http://$using:SubCADNSName/CertEnroll/%3%8%9.crl"
certutil -setreg CA\CACertPublicationURLs "1:C:\Windows\system32\CertSrv\CertEnroll\%1_%3%4.crt\n2:http://$using:SubCADNSName/CertEnroll/%1_%3%4.crt"
net stop certsvc 
net start certsvc	
net stop certsvc 
net start certsvc
} -credential $CredentialsSubCA


