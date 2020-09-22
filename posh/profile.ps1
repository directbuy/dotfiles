

function connect($pshost) {
    $credential = Get-Credential
    $options = New-PSSessionOption -SkipCACheck -SkipCNCheck
    $session = New-PSSession -Credential $cred $pshost -UseSSL -SessionOption $options -Authentication Default

    Enter-PSSession $session
}

function setup_dircolors() {
    $dircolors = "C:\u\dotfiles\zsh\.dircolors"
    if ((Test-Path $dircolors) -and (!(Test-Path "${env:HOMEDRIVE}${env:HOMEPATH}\.dircolors"))) {
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
                &$python -m venv .wenv
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


function djact() {
    if ((Test-Path ".wenv") -and (Test-Path ".\.wenv\scripts\activate.ps1")) {
        . ".\.wenv\scripts\activate.ps1" 
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
    $weather = (Invoke-WebRequest "https://wttr.in/${city}" -UserAgent "curl").content
    $weather = $weather -split "`n"
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
    if (($virtualenv) -and ($virtualenv.Length -gt 0)) {
        $venv_name = Split-Path $virtualenv -Leaf
        if ($venv_name -eq ".wenv") {
            $venv_name = Split-path -Leaf (Split-Path $virtualenv -Parent)
        }
        $virtualenv = $venv_name
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
# MIIOCgYJKoZIhvcNAQcCoIIN+zCCDfcCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUbTBFN+joz7b2LA5aAHRttFn6
# YLmgggtBMIIFRDCCBCygAwIBAgIRAPObRmxze0JQ5eGP2ElORJ8wDQYJKoZIhvcN
# AQELBQAwfDELMAkGA1UEBhMCR0IxGzAZBgNVBAgTEkdyZWF0ZXIgTWFuY2hlc3Rl
# cjEQMA4GA1UEBxMHU2FsZm9yZDEYMBYGA1UEChMPU2VjdGlnbyBMaW1pdGVkMSQw
# IgYDVQQDExtTZWN0aWdvIFJTQSBDb2RlIFNpZ25pbmcgQ0EwHhcNMTkxMjAyMDAw
# MDAwWhcNMjIxMjAxMjM1OTU5WjCBtDELMAkGA1UEBhMCVVMxDjAMBgNVBBEMBTQ2
# NDEwMRAwDgYDVQQIDAdJbmRpYW5hMRUwEwYDVQQHDAxNZXJyaWxsdmlsbGUxFjAU
# BgNVBAkMDTg0NTAgQnJvYWR3YXkxKTAnBgNVBAoMIERpcmVjdGJ1eSBIb21lIElt
# cHJvdmVtZW50LCBJbmMuMSkwJwYDVQQDDCBEaXJlY3RidXkgSG9tZSBJbXByb3Zl
# bWVudCwgSW5jLjCCASIwDQYJKoZIhvcNAQEBBQADggEPADCCAQoCggEBALJqKpxa
# e2Zx7jKFSB+Bev1xV7o4u1Nghup8yVR7/AUvJr4IAMVYMc4P9OfnCexCRex1hAgw
# NOYo9IzQxtHfGq7eQQUJA9EP8g5/3BiwrM6dJggbA6FZ6AsM4A+lac5LFgjrcISj
# qgcJ1PlEGmRSJqF6XrTfxVwq5e3Bl2iTI+IlHqdNTAbplv9F1cxfQFno6Ym1oa6M
# uvAJoYTb7Ma2Ljl9cg6y34ZQg19vJMZ8cOgkuhY3NuuFrYiQCbdqK3UDql6fKRR0
# NvlBLj+KN1JfehfBNp6sUDBEALq1FeVCABQwuEchSRYzJZ23OGySXccV9hXrj4nJ
# Yo7k6FSi19PX75UCAwEAAaOCAYYwggGCMB8GA1UdIwQYMBaAFA7hOqhTOjHVir7B
# u61nGgOFrTQOMB0GA1UdDgQWBBRkJZWUpSBvVXUVZpdn5UTUXRd1yjAOBgNVHQ8B
# Af8EBAMCB4AwDAYDVR0TAQH/BAIwADATBgNVHSUEDDAKBggrBgEFBQcDAzARBglg
# hkgBhvhCAQEEBAMCBBAwQAYDVR0gBDkwNzA1BgwrBgEEAbIxAQIBAwIwJTAjBggr
# BgEFBQcCARYXaHR0cHM6Ly9zZWN0aWdvLmNvbS9DUFMwQwYDVR0fBDwwOjA4oDag
# NIYyaHR0cDovL2NybC5zZWN0aWdvLmNvbS9TZWN0aWdvUlNBQ29kZVNpZ25pbmdD
# QS5jcmwwcwYIKwYBBQUHAQEEZzBlMD4GCCsGAQUFBzAChjJodHRwOi8vY3J0LnNl
# Y3RpZ28uY29tL1NlY3RpZ29SU0FDb2RlU2lnbmluZ0NBLmNydDAjBggrBgEFBQcw
# AYYXaHR0cDovL29jc3Auc2VjdGlnby5jb20wDQYJKoZIhvcNAQELBQADggEBAG+U
# CFxgpbyU/37LEaqrGd4jc4oea7K6zyNt4sHBhONAfDY83NDso2/drgjBob2WmTym
# D7N4dbHRhakTKLlEDDV2i84DWic5nutilsNfRzzKvMAoLM4izBx7BKwG81HY5BN8
# JBXnofxY63ieigCatn31p1mw1lFPOTMDQGzmMGQO9krl2aiEkb8s2bV5LsGxEukX
# nWXlRJc5BHbeI5u4M3Vmh+aR+8bzGyQAqLRWzEk5Xpt4Olvf2+IDj+sNfOwas2T6
# C0QqwztM8O5XHufSjUWJWqfK46QRvIY8OelDOaWy6yd+8jyrTnsV7e5UA0VqQmPF
# SfLmEsjeyQnAeHUBJTAwggX1MIID3aADAgECAhAdokgwb5smGNCC4JZ9M9NqMA0G
# CSqGSIb3DQEBDAUAMIGIMQswCQYDVQQGEwJVUzETMBEGA1UECBMKTmV3IEplcnNl
# eTEUMBIGA1UEBxMLSmVyc2V5IENpdHkxHjAcBgNVBAoTFVRoZSBVU0VSVFJVU1Qg
# TmV0d29yazEuMCwGA1UEAxMlVVNFUlRydXN0IFJTQSBDZXJ0aWZpY2F0aW9uIEF1
# dGhvcml0eTAeFw0xODExMDIwMDAwMDBaFw0zMDEyMzEyMzU5NTlaMHwxCzAJBgNV
# BAYTAkdCMRswGQYDVQQIExJHcmVhdGVyIE1hbmNoZXN0ZXIxEDAOBgNVBAcTB1Nh
# bGZvcmQxGDAWBgNVBAoTD1NlY3RpZ28gTGltaXRlZDEkMCIGA1UEAxMbU2VjdGln
# byBSU0EgQ29kZSBTaWduaW5nIENBMIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIB
# CgKCAQEAhiKNMoV6GJ9J8JYvYwgeLdx8nxTP4ya2JWYpQIZURnQxYsUQ7bKHJ6aZ
# y5UwwFb1pHXGqQ5QYqVRkRBq4Etirv3w+Bisp//uLjMg+gwZiahse60Aw2Gh3Gll
# bR9uJ5bXl1GGpvQn5Xxqi5UeW2DVftcWkpwAL2j3l+1qcr44O2Pej79uTEFdEiAI
# Weg5zY/S1s8GtFcFtk6hPldrH5i8xGLWGwuNx2YbSp+dgcRyQLXiX+8LRf+jzhem
# LVWwt7C8VGqdvI1WU8bwunlQSSz3A7n+L2U18iLqLAevRtn5RhzcjHxxKPP+p8YU
# 3VWRbooRDd8GJJV9D6ehfDrahjVh0wIDAQABo4IBZDCCAWAwHwYDVR0jBBgwFoAU
# U3m/WqorSs9UgOHYm8Cd8rIDZsswHQYDVR0OBBYEFA7hOqhTOjHVir7Bu61nGgOF
# rTQOMA4GA1UdDwEB/wQEAwIBhjASBgNVHRMBAf8ECDAGAQH/AgEAMB0GA1UdJQQW
# MBQGCCsGAQUFBwMDBggrBgEFBQcDCDARBgNVHSAECjAIMAYGBFUdIAAwUAYDVR0f
# BEkwRzBFoEOgQYY/aHR0cDovL2NybC51c2VydHJ1c3QuY29tL1VTRVJUcnVzdFJT
# QUNlcnRpZmljYXRpb25BdXRob3JpdHkuY3JsMHYGCCsGAQUFBwEBBGowaDA/Bggr
# BgEFBQcwAoYzaHR0cDovL2NydC51c2VydHJ1c3QuY29tL1VTRVJUcnVzdFJTQUFk
# ZFRydXN0Q0EuY3J0MCUGCCsGAQUFBzABhhlodHRwOi8vb2NzcC51c2VydHJ1c3Qu
# Y29tMA0GCSqGSIb3DQEBDAUAA4ICAQBNY1DtRzRKYaTb3moqjJvxAAAeHWJ7Otcy
# wvaz4GOz+2EAiJobbRAHBE++uOqJeCLrD0bs80ZeQEaJEvQLd1qcKkE6/Nb06+f3
# FZUzw6GDKLfeL+SU94Uzgy1KQEi/msJPSrGPJPSzgTfTt2SwpiNqWWhSQl//BOvh
# dGV5CPWpk95rcUCZlrp48bnI4sMIFrGrY1rIFYBtdF5KdX6luMNstc/fSnmHXMdA
# TWM19jDTz7UKDgsEf6BLrrujpdCEAJM+U100pQA1aWy+nyAlEA0Z+1CQYb45j3qO
# TfafDh7+B1ESZoMmGUiVzkrJwX/zOgWb+W/fiH/AI57SHkN6RTHBnE2p8FmyWRno
# ao0pBAJ3fEtLzXC+OrJVWng+vLtvAxAldxU0ivk2zEOS5LpP8WKTKCVXKftRGceh
# JUBqhFfGsp2xvBwK2nxnfn0u6ShMGH7EezFBcZpLKewLPVdQ0srd/Z4FUeVEeN0B
# 3rF1mA1UJP3wTuPi+IO9crrLPTru8F4XkmhtyGH5pvEqCgulufSe7pgyBYWe6/mD
# KdPGLH29OncuizdCoGqC7TtKqpQQpOEN+BfFtlp5MxiS47V1+KHpjgolHuQe8Z9a
# hyP/n6RRnvs5gBHN27XEp6iAb+VT1ODjosLSWxr6MiYtaldwHDykWC6j81tLB9wy
# WfOHpxptWDGCAjMwggIvAgEBMIGRMHwxCzAJBgNVBAYTAkdCMRswGQYDVQQIExJH
# cmVhdGVyIE1hbmNoZXN0ZXIxEDAOBgNVBAcTB1NhbGZvcmQxGDAWBgNVBAoTD1Nl
# Y3RpZ28gTGltaXRlZDEkMCIGA1UEAxMbU2VjdGlnbyBSU0EgQ29kZSBTaWduaW5n
# IENBAhEA85tGbHN7QlDl4Y/YSU5EnzAJBgUrDgMCGgUAoHgwGAYKKwYBBAGCNwIB
# DDEKMAigAoAAoQKAADAZBgkqhkiG9w0BCQMxDAYKKwYBBAGCNwIBBDAcBgorBgEE
# AYI3AgELMQ4wDAYKKwYBBAGCNwIBFTAjBgkqhkiG9w0BCQQxFgQUJnUx3y6LdJQS
# 8Uq9HLFybXEVdkQwDQYJKoZIhvcNAQEBBQAEggEAqI8zvp1P70RdM2VeRBZI0o1B
# mmq6go0eK0U0+q4AMbKnhfPo9a124vI/qVmQPEma3hxlM+k2OMOti7+OFdzYB5pj
# Reknb58YmlsZlz6hwozUvER8/Eb+1k64P/FILZA2BPHkhzvkKh8MJ3z+EQ3u+CLp
# yGlLqOy1i2CfG1JCcwQeJuzoX3wWXzxegUF2QA06TLfvITyc8LiB+VanyzXw49ud
# /yaT8j6mTGijnI8Yj+Y6XT7qCGZdRUeVvxG02yyP6cp6UxNzoYberMFt+Mv86O7r
# OJyqe6+jCi+qUD0AhmakQDYPAfF/WXE727iwF7G7Ihy0ko1FrjMVW5fxLq69Cg==
# SIG # End signature block
