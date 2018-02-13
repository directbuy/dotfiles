Install-PackageProvider -Name NuGet -Force -Confirm:$false
Set-PSRepository -Name PSGallery -InstallationPolicy Trusted
# Install-Module posh-git
# Install-Module oh-my-posh
