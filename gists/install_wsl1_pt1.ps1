#---WSL Prepwork---
#create u directory at c:\u
New-Item -ItemType directory -Path c:\u
[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12

#Install Chocolatey & friends
Install-PackageProvider -name Nuget -Force -Confirm:$false
refreshenv
Install-Module powershellget -force
install-module dircolors -force
Set-ExecutionPolicy Bypass -Scope Process -Force; iex ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))
refreshenv
choco install git -y
choco install python3 --version 3.8.5 -y --params "/InstallDir:c:\python38"
choco install conemu -y

#---Windows Subsystems/Features---
Get-WindowsOptionalFeature -FeatureName *linux* -Online
# Create AppModelUnlock if it doesn't exist, required for enabling Developer Mode
$RegistryKeyPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\AppModelUnlock"
if (-not(Test-Path -Path $RegistryKeyPath)) {
    New-Item -Path $RegistryKeyPath -ItemType Directory -Force
}

# Add registry value to enable Developer Mode
New-ItemProperty -Path $RegistryKeyPath -Name AllowDevelopmentWithoutDevLicense -PropertyType DWORD -Value 1

# You will have to reboot after the following step
Enable-WindowsOptionalFeature -Online -FeatureName Microsoft-Windows-Subsystem-Linux
