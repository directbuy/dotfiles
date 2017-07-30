# Chocolatey setup on windows #

1.  Open command prompt (elevated)

2.  Install chcolately

        @"%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe" -NoProfile -ExecutionPolicy Bypass -Command "iex ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))"
        SET "PATH=%PATH%;%ALLUSERSPROFILE%\chocolatey\bin"

3.  Setup developer mode on windows (prep for wsl)

        # Create AppModelUnlock if it doesn't exist, required for enabling Developer Mode
        $RegistryKeyPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\AppModelUnlock"
        if (-not(Test-Path -Path $RegistryKeyPath)) {
            New-Item -Path $RegistryKeyPath -ItemType Directory -Force
        }

        # Add registry value to enable Developer Mode
        New-ItemProperty -Path $RegistryKeyPath -Name AllowDevelopmentWithoutDevLicense -PropertyType DWORD -Value 1
        $dir = 'c:\u';
        if (!(Test-Path -Path $dir )) {
            New-Item -ItemType directory -Path $dir
        }


4.  Install choco packages (base)

        choco install chrome conemu python3 python2 git

5.  Start conemu and open up git-bash to pull dotfiles
    and the wsl distribution switcher

        cd /c/u
        git clone https://github.com/2ps/dotfiles
        git clone https://github.com/RoliSoft/WSL-Distribution-Switcher

6.  Import conemu settings from dotfiles (c:\u\dotfiles\cygwin\conemu.team.colors.xml)

7.  Download the centos pre-built from docker (in powershell)

        cd /u/WSL-Distribution-Switcher
        c:\python36\python get-prebuilt.py centos

8.  Install wsl (this will require a reboot)

        enable-windowsoptionalfeature -featurename microsoft-windows-subsystem-linux -online

9.  After reboot, start bash (not git-bash but the other one)
    and accept the license agreement.  Exit bash.

10. Install centos as your wsl (in powershell admin),  Make sure to
    switch the default user to root

        cd /u/WSL-Distribution-Switcher
        c:/python36/python install centos
        lxrun /setdefaultuser root

11. Start up bash again (centos in conemu `+` menu) and verify that
    we are running centos:

        python -m platform

12. Setup centos with the handy 2ps setup script

        echo "8.8.8.8" >> /etc/resolv.conf
        yum -y install wget
        ln -s /mnt/c/u/ /u
        chmod a+x /u/dotfiles/gists/wsl_centos_setup.sh
        /u/dotfiles/gists/wsl_ventos_setup.sh
        # this will take about 30-45 minutes

13. Install 2ps dotfiles in centos

        chmod a+x /u/dotfiles/wsl-install
        /u/dotfiles/wsl-install

14. Copy over and setup up .ssh and .gnupg keys

