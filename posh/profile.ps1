

function connect($pshost) {
    $credential = Get-Credential
    $options = New-PSSessionOption -SkipCACheck -SkipCNCheck
    $session = New-PSSession -Credential $cred $pshost -UseSSL -SessionOption $options -Authentication Default

    Enter-PSSession $session
}

function setup_dircolors() {
    $dircolors = "C:\u\dotfiles\zsh\.dircolors"
    if (Test-Path $dircolors -and (!Test-Path "${env:HOMEDRIVE}${env:HOMEPATH}\.dircolors")) {
        copy $dircolors "${env:HOMEDRIVE}${env:HOMEPATH}"
        Update-DirColors $dircolors
    }
}

function venv($name="") {
    if (!(Test-Path ".wenv")) {
        $installed_python = $null
        $pythons = @{
            "38" = "c:\python38\python.exe";
            "37" = "c:\python37\python.exe";
            "36" = "c:\python36\python.exe" }
        foreach ($x in $pythons.keys) {
            $python = $pythons[$x]
            if (Test-Path $python) {
                $python -m venv .wenv
                break
            }
        }
        Write-Host "venv created with $python"
    }
    else {
        Write-Host "activating existing virtual environment"
        djact
    }
    Write-Host "upgrading pip"
    &python.exe -m pip -q install -U pip wheel setuptools | Out-Host
    if (Test-Path ".\requirements.txt") {
        Write-Host "installing requirements"
        &pip -q install -r requirements.txt | Out-Host
    }

    if (Test-Path ".\setup.py") {
        Write-Host "installing setup.py dependencies"
        &pip -q install -e .
    }
}

function venv($name="") {
    $env_dir = "$env:homedrive$env:HOMEPATH\envs"
    if (!(Test-Path $env_dir)) {
        New-Item $env_dir -ItemType Directory
    }
    if ($name -eq "") {
        $name = ([io.fileinfo]"$pwd").basename
    }
    $env_dirs = "${env_dir}\${name}", ".wenv"

    if (!(Test-Path "$env_dir\$name")) {
        $installed_python = $null
        $pythons = @{
            "38" = "c:\python38\python.exe";
            "37" = "c:\python37\python.exe";
            "36" = "c:\python36\python.exe" }
        foreach ($x in $pythons.keys) {
            $python = $pythons[$x]
            if (Test-Path $python) {
                mkvirtualenv $name -Python $python
                $installed_python = $x
                break
            }
        }
        Write-Host "venv created with $python"
        Write-Host "installing windows wheels"
        &pip -q install C:\u\wheels\python_ldap-3.1.0-cp${installed_python}-cp${installed_python}m-win_amd64.whl | Out-Host
    }
    else {
        Write-Host "activating existing virtual environment"
        workon $name
    }
    Write-Host "upgrading pip"
    &python.exe -m pip -q install -U pip wheel setuptools | Out-Host
    if (Test-Path ".\requirements.txt") {
        Write-Host "installing requirements"
        &pip -q install -r requirements.txt | Out-Host
    }

    if (Test-Path ".\setup.py") {
        Write-Host "installing setup.py dependencies"
        &pip -q install -e .
    }
}


function djact() {
    if ((Test-Path ".wenv") -and (Test-Path ".wenv\scripts\activate.ps1")) {
        . .wenv\scripts\activate.ps1
    }
    else {
        $name = ([io.fileinfo]"$pwd").basename
        workon $name
    }
}

function dj() {
    if (!(Test-Path .\manage.py)) {
        Write-Host "no django found here"
        return
    }
    &python manage.py @args
}

function djsp() {
    dj shell_plus --quiet-load
}

function weather($city="Chicago") {
    $weather = (curl "https://wttr.in/${city}").ParsedHtml.body.outerText
    $weather = $weather -split "`r`n"
    for ($x = 0; $x -lt 17; ++$x) {
        Write-Host $weather[$x]
    }
}

$env:virtual_env_disable_prompt=1
function global:prompt {
    $dir = "$pwd".toLower().replace("\", "/");
    $virtualenv = $env:VIRTUAL_ENV
    $commit = $null
    $output = git status --porcelain --branch 2>$null | Out-String
    $branch = $null
    $dirty = $false
    $commit = $null
    if ($output) {
        $output = $output -split "`r`n"
        $branch = $output[0]
        $branch = $branch.split('.')[0].substring(3)
        if ($branch -eq "No commits yet on master") {
            $branch = "<empty>"
        }
        if ($output.Count -gt 2) {
            $dirty = $true
        }
        $commit = git rev-parse --short HEAD 2>&1
    }
    $pieces1 = New-Object System.Collections.ArrayList;
    $length1 = 3
    $z = $pieces1.Add(($dir, [ConsoleColor]::Gray))
    $length1 += 2 + $dir.Length
    if ($virtualenv -and ($virtualenv.Length -gt 0)) {
        $virtualenv = Split-Path $virtualenv -Leaf
        $z = $pieces1.Add(("($virtualenv)", [ConsoleColor]::DarkCyan))
        $length1 += 6 + $virtualenv.Length
    }
    if ($commit) {
        $commit = $commit.substring(0, 7);
        $piece = "[$branch $commit]"
        $z = $pieces1.Add(($piece, [ConsoleColor]::DarkCyan))
        $length1 += 4 + $piece.Length
        # $line1 = "$line1━━ [$branch $commit] ";

        if ($dirty) {
            $z = $pieces1.Add(("*", [ConsoleColor]::White))
            $length1 += 5
            # $line1 = "$line1* "
        }
    }
    $dt = Get-Date -UFormat "%Y.%m.%d %I:%M %p"
    $computer = $env:COMPUTERNAME
    $user = $env:USERNAME
    $pieces2 = New-Object System.Collections.ArrayList
    $length2 = 3
    $z = $pieces2.Add(("posh", [ConsoleColor]::DarkGreen))
    $length2 += 6
    $piece = "${user}@${computer}"
    $z = $pieces2.Add(($piece, [ConsoleColor]::Gray))
    $length2 += 4 + $piece.Length
    $z = $pieces2.Add(($dt, [ConsoleColor]::Gray))
    $length2 += 4 + $dt.Length
    $padding1 = ""
    $padding2 = ""
    if ($length1 -lt $length2) {
        $padding1 = ""
        for ($x = 0; $x -lt ($length2 - $length1); $x++) {
            $padding1 += "━"
        }
    }
    elseif ($length2 -lt $length1) {
        for ($x = 0; $x -lt ($length1 - $length2); $x++) {
            $padding2 += "━"
        }
    }
    Write-Host
    Write-Host "┏" -ForegroundColor DarkGreen -NoNewline
    foreach ($x in $pieces1) {
        $st = $x[0];
        $color = $x[1];
        Write-Host "━━" -ForegroundColor DarkGreen -NoNewline
        Write-Host " $st " -ForegroundColor $color -NoNewline
    }
    if ($padding1) {
        Write-Host $padding1 -ForegroundColor DarkGreen -NoNewline
    }
    Write-Host "━┓" -ForegroundColor DarkGreen
    Write-Host "┣" -ForegroundColor DarkGreen -NoNewline
    foreach ($x in $pieces2) {
        $st = $x[0];
        $color = $x[1];
        Write-Host "━━" -ForegroundColor DarkGreen -NoNewline
        Write-Host " $st " -ForegroundColor $color -NoNewline
    }
    if ($padding2) {
        Write-Host $padding2 -ForegroundColor DarkGreen -NoNewline
    }
    Write-Host "━┛" -ForegroundColor DarkGreen
    Write-Host "┗ " -nonewline -ForegroundColor DarkGreen
    Write-Host "➤" -foregroundcolor white -nonewline
    return " "
}


[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12
Import-Module DirColors
ipmo DockerCompletion
setup_dircolors
Set-PSReadlineKeyHandler -Key Ctrl+d -Function DeleteCharOrExit

# SIG # Begin signature block
# MIIM8gYJKoZIhvcNAQcCoIIM4zCCDN8CAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUoFH84/MT4/ti1/YrsFEPdam4
# 7UKgggonMIIExjCCA66gAwIBAgIQSHCA5QCreD9sNHHzrnj2njANBgkqhkiG9w0B
# AQsFADB/MQswCQYDVQQGEwJVUzEdMBsGA1UEChMUU3ltYW50ZWMgQ29ycG9yYXRp
# b24xHzAdBgNVBAsTFlN5bWFudGVjIFRydXN0IE5ldHdvcmsxMDAuBgNVBAMTJ1N5
# bWFudGVjIENsYXNzIDMgU0hBMjU2IENvZGUgU2lnbmluZyBDQTAeFw0xNzA2MTIw
# MDAwMDBaFw0xOTA3MDkyMzU5NTlaMF4xCzAJBgNVBAYTAlVTMRAwDgYDVQQIDAdJ
# bmRpYW5hMRUwEwYDVQQHDAxtZXJyaWxsdmlsbGUxEjAQBgNVBAoMCURpcmVjdGJ1
# eTESMBAGA1UEAwwJRGlyZWN0YnV5MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIB
# CgKCAQEApehwhW7NkmPyyWEMge9/jtnnDmGaj4IFIliVxm7SjgHHyrGT4A0CS1j+
# KoP3THqMdkBmsbROcuCth7edHn9sILsX67QiuRayn0ebzL72ltKAmCuM4mIbvpJd
# PHMw9etqHL870L4WgzeMjtBp2CY0stsa6YJs9jj/eShKgIZoYORgRCNLhHshQEMc
# 7X9iLxPGZzMB/UesKg1AvcSI90mPCLfaCaPUoSJ5wmK3FWJBtg085kypKUSi0iwB
# tcbeHaT8X8mxF6G7IzDKQcPd461b3oMSDCL4bpRDT46d2SUc3nymuOHSrC9XDFdH
# gfw2wS+uSLpoJVIWEhxQX2wi6ltvWQIDAQABo4IBXTCCAVkwCQYDVR0TBAIwADAO
# BgNVHQ8BAf8EBAMCB4AwKwYDVR0fBCQwIjAgoB6gHIYaaHR0cDovL3N2LnN5bWNi
# LmNvbS9zdi5jcmwwYQYDVR0gBFowWDBWBgZngQwBBAEwTDAjBggrBgEFBQcCARYX
# aHR0cHM6Ly9kLnN5bWNiLmNvbS9jcHMwJQYIKwYBBQUHAgIwGQwXaHR0cHM6Ly9k
# LnN5bWNiLmNvbS9ycGEwEwYDVR0lBAwwCgYIKwYBBQUHAwMwVwYIKwYBBQUHAQEE
# SzBJMB8GCCsGAQUFBzABhhNodHRwOi8vc3Yuc3ltY2QuY29tMCYGCCsGAQUFBzAC
# hhpodHRwOi8vc3Yuc3ltY2IuY29tL3N2LmNydDAfBgNVHSMEGDAWgBSWO1PweTOX
# r32D7y4rzMq3hh5yZjAdBgNVHQ4EFgQUsRk2ROSUiNHlfiviHyjMJ6+t+LkwDQYJ
# KoZIhvcNAQELBQADggEBAHjhoJSANQhrF5KB4AwVXe6lGxCb2UxMDgvAjlv9OPrm
# b0GMJZcKQmpuq2UlIk9WFJuh4dllZXXggprxG+cZ+0flcxWE1SqtYKDLtX3c2Z60
# Mop24nMVipBOSBZsXAnwwuuOKKl7DVBPhWIWPNawtn3bqBDVPP6MbtHFF3NnMVzj
# 0o8av0D/0b4KXwg0XS9YH/Rc3T8uZ5rmRFg5MFWG2J8UhvMsl63Wf0RggOADlbnx
# E7nUH3YpB7eijGX3fZLBjCAlpW10IF8ut8vvxcoKxgd9wHLzHnZVSqN8xbR1554W
# YREkF7v6bpsn4RhUBKIIRIS1x1n5w2pmJyDs9eFbNxAwggVZMIIEQaADAgECAhA9
# eNf5dklgsmF99PAeyoYqMA0GCSqGSIb3DQEBCwUAMIHKMQswCQYDVQQGEwJVUzEX
# MBUGA1UEChMOVmVyaVNpZ24sIEluYy4xHzAdBgNVBAsTFlZlcmlTaWduIFRydXN0
# IE5ldHdvcmsxOjA4BgNVBAsTMShjKSAyMDA2IFZlcmlTaWduLCBJbmMuIC0gRm9y
# IGF1dGhvcml6ZWQgdXNlIG9ubHkxRTBDBgNVBAMTPFZlcmlTaWduIENsYXNzIDMg
# UHVibGljIFByaW1hcnkgQ2VydGlmaWNhdGlvbiBBdXRob3JpdHkgLSBHNTAeFw0x
# MzEyMTAwMDAwMDBaFw0yMzEyMDkyMzU5NTlaMH8xCzAJBgNVBAYTAlVTMR0wGwYD
# VQQKExRTeW1hbnRlYyBDb3Jwb3JhdGlvbjEfMB0GA1UECxMWU3ltYW50ZWMgVHJ1
# c3QgTmV0d29yazEwMC4GA1UEAxMnU3ltYW50ZWMgQ2xhc3MgMyBTSEEyNTYgQ29k
# ZSBTaWduaW5nIENBMIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAl4Me
# ABavLLHSCMTXaJNRYB5x9uJHtNtYTSNiarS/WhtR96MNGHdou9g2qy8hUNqe8+df
# J04LwpfICXCTqdpcDU6kDZGgtOwUzpFyVC7Oo9tE6VIbP0E8ykrkqsDoOatTzCHQ
# zM9/m+bCzFhqghXuPTbPHMWXBySO8Xu+MS09bty1mUKfS2GVXxxw7hd924vlYYl4
# x2gbrxF4GpiuxFVHU9mzMtahDkZAxZeSitFTp5lbhTVX0+qTYmEgCscwdyQRTWKD
# trp7aIIx7mXK3/nVjbI13Iwrb2pyXGCEnPIMlF7AVlIASMzT+KV93i/XE+Q4qITV
# RrgThsIbnepaON2b2wIDAQABo4IBgzCCAX8wLwYIKwYBBQUHAQEEIzAhMB8GCCsG
# AQUFBzABhhNodHRwOi8vczIuc3ltY2IuY29tMBIGA1UdEwEB/wQIMAYBAf8CAQAw
# bAYDVR0gBGUwYzBhBgtghkgBhvhFAQcXAzBSMCYGCCsGAQUFBwIBFhpodHRwOi8v
# d3d3LnN5bWF1dGguY29tL2NwczAoBggrBgEFBQcCAjAcGhpodHRwOi8vd3d3LnN5
# bWF1dGguY29tL3JwYTAwBgNVHR8EKTAnMCWgI6Ahhh9odHRwOi8vczEuc3ltY2Iu
# Y29tL3BjYTMtZzUuY3JsMB0GA1UdJQQWMBQGCCsGAQUFBwMCBggrBgEFBQcDAzAO
# BgNVHQ8BAf8EBAMCAQYwKQYDVR0RBCIwIKQeMBwxGjAYBgNVBAMTEVN5bWFudGVj
# UEtJLTEtNTY3MB0GA1UdDgQWBBSWO1PweTOXr32D7y4rzMq3hh5yZjAfBgNVHSME
# GDAWgBR/02Wnwt3su/AwCfNDOfoCrzMxMzANBgkqhkiG9w0BAQsFAAOCAQEAE4Ua
# HmmpN/egvaSvfh1hU/6djF4MpnUeeBcj3f3sGgNVOftxlcdlWqeOMNJEWmHbcG/a
# IQXCLnO6SfHRk/5dyc1eA+CJnj90Htf3OIup1s+7NS8zWKiSVtHITTuC5nmEFvwo
# sLFH8x2iPu6H2aZ/pFalP62ELinefLyoqqM9BAHqupOiDlAiKRdMh+Q6EV/WpCWJ
# mwVrL7TJAUwnewusGQUioGAVP9rJ+01Mj/tyZ3f9J5THujUOiEn+jf0or0oSvQ2z
# lwXeRAwV+jYrA9zBUAHxoRFdFOXivSdLVL4rhF4PpsN0BQrvl8OJIrEfd/O9zUPU
# 8UypP7WLhK9k8tAUITGCAjUwggIxAgEBMIGTMH8xCzAJBgNVBAYTAlVTMR0wGwYD
# VQQKExRTeW1hbnRlYyBDb3Jwb3JhdGlvbjEfMB0GA1UECxMWU3ltYW50ZWMgVHJ1
# c3QgTmV0d29yazEwMC4GA1UEAxMnU3ltYW50ZWMgQ2xhc3MgMyBTSEEyNTYgQ29k
# ZSBTaWduaW5nIENBAhBIcIDlAKt4P2w0cfOuePaeMAkGBSsOAwIaBQCgeDAYBgor
# BgEEAYI3AgEMMQowCKACgAChAoAAMBkGCSqGSIb3DQEJAzEMBgorBgEEAYI3AgEE
# MBwGCisGAQQBgjcCAQsxDjAMBgorBgEEAYI3AgEVMCMGCSqGSIb3DQEJBDEWBBSU
# ehVJHKRywgWM6zaoIRLREAmdAjANBgkqhkiG9w0BAQEFAASCAQBgovett/3ELdiF
# QSUm1ZgzFTNuYEUeo2xyuARI08m7KWs7bapnW8EAUjziyfsX1x9/ZZ/Nn9EY/3Hb
# 25i1ZPBP3zIBkIizN0Dr1VsImwj+2lPwLaP/FBzf27o2TISPOaCosSCbH735S9+/
# eR6QdbUTppGN5yGGsy0s6pObDNwAAFYHqoohoRB3BTHm5A52Uw8+hBMN9J0OAB3m
# N4SDB8MelBxCzvD+y9ZmHCJZw48iM8gx2JOLm9MlAVM5Le7khZHrvbu2or56URbZ
# PvE7oMsCs2YMKx6ZiZ3sLmIeaCRMu7CE6yJiefeosN9hPY+ggUD0a5Li7T2Z5CUP
# Y1B9ej30
# SIG # End signature block
