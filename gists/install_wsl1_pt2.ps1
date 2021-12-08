# setup tls 1.2
[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12

#---Download latest ubuntu---
function ensure($path) {
    if (!(Test-path $path)) {
        mkdir $path
    }
}
function download($url, $filename) {
    if (!(Test-Path $filename)) {
        $client = New-Object System.Net.WebClient
        $client.DownloadFile($url, $filename)
        & msiexec /i $filename /quiet
    }
}

$domain = Read-Host "enter your email domain example directbuy.com"
ensure C:\u
ensure c:\u\downloads
Add-MpPreference -ExclusionPath "${env:localappdata}\lxss"
Add-MpPreference -ExclusionPath "c:\u"
$filename = "c:\u\downloads\bionic.zip"
download "https://aka.ms/wsl-ubuntu-1804" $filename
ensure "c:\wsl"
Expand-Archive $filename "c:\wsl\ubuntu"
cd \wsl\ubuntu
& .\ubuntu1804.exe install --root
& .\ubuntu1804.exe run "adduser --force-badname --gecos '' $env:username"
& .\ubuntu1804.exe run "echo '$env:username    ALL=(ALL:ALL)    NOPASSWD: ALL' >/etc/sudoers.d/10-$env:username"
& .\ubuntu1804.exe run "chmod 0600 /etc/sudoers.d/10-$env:username"
& .\ubuntu1804.exe run "add-apt-repository universe"
& .\ubuntu1804.exe run "apt update"
& .\ubuntu1804.exe run "apt-get install sudo wget man dos2unix git p7zip-full xz-utils"
& .\ubuntu1804.exe run "ln -s /mnt/c/u /u"
& .\ubuntu1804.exe run "if [[ -d /u/dotfiles ]] ; then rm -rf /u/dotfiles ; fi"
& .\ubuntu1804.exe run "git config --global user.name $env:username"
& .\ubuntu1804.exe run "git config --global user.email ${env:username}@$domain"
& .\ubuntu1804.exe run "cd /u && git clone https://github.com/directbuy/dotfiles"
Write-Host "setting up wsl.conf"
& .\ubuntu1804.exe run "echo '[automount]' >>/etc/wsl.conf"
& .\ubuntu1804.exe run "echo 'options=metadata,dmask=22,fmask=22' >>/etc/wsl.conf"
& .\ubuntu1804.exe run "cp /u/dotfiles/gists/wsl_ubuntu_setup.sh /tmp/wsl_setup.sh"
& .\ubuntu1804.exe run "chmod a+x /tmp/wsl_setup.sh && /tmp/wsl_setup.sh"
& .\ubuntu1804.exe config --default-user $env:username
& .\ubuntu1804.exe run "/u/dotfiles/wsl-install"
& .\ubuntu1804.exe run "git config --global user.name $env:username"
& .\ubuntu1804.exe run "git config --global user.email ${env:username}@$domain"
