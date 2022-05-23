if (Test-Path "c:\windows\system32\wsl.exe") {
    ###> I like Bash. Give me more bash ###
    $bashCommands = "awk", "emacs", "grep", "head", "less", "ls", "man", "sed", "seq", "ssh", "tail", "touch"

    $bashCommands | ForEach-Object { Invoke-Expression @"
    Remove-Item Alias:$_ -Force -ErrorAction:Ignore
    function global:$_() {
        for (`$i = 0; `$i -lt `$args.Count; `$i++) {

            if (Split-Path `$args[`$i] -IsAbsolute -ErrorAction Ignore) {
                `$args[`$i] = Format_WslArgument (wsl.exe wslpath (`$args[`$i] -replace "\\", "/"))

            } elseif (Test-Path `$args[`$i] -ErrorAction Ignore) {
                `$args[`$i] = Format_WslArgument (`$args[`$i] -replace "\\", "/")
            }
        }

        if (`$input.MoveNext()) {
            `$input.Reset()
            `$input | wsl.exe $_ (`$args -split ' ')
        } else {
            wsl.exe $_ (`$args -split ' ')
        }
    }
"@
    }

    Register-ArgumentCompleter -CommandName $bashCommands -ScriptBlock {
        param($wordToComplete, $commandAst, $cursorPosition)

        $F = switch ($commandAst.CommandElements[0].Value) {
            {$_ -in "awk", "grep", "head", "less", "ls", "sed", "seq", "tail"} {
                "_longopt"
                break
            }

            "man" {
                "_man"
                break
            }

            "ssh" {
                "_ssh"
                break
            }

            Default {
                "_minimal"
                break
            }
        }

        $COMP_LINE = "`"$commandAst`""
        $COMP_WORDS = "('$($commandAst.CommandElements.Extent.Text -join "' '")')" -replace "''", "'"
        for ($i = 1; $i -lt $commandAst.CommandElements.Count; $i++) {
            $extent = $commandAst.CommandElements[$i].Extent
            if ($cursorPosition -lt $extent.EndColumnNumber) {
                $previousWord = $commandAst.CommandElements[$i - 1].Extent.Text
                $COMP_CWORD = $i
                break
            } elseif ($cursorPosition -eq $extent.EndColumnNumber) {
                $previousWord = $extent.Text
                $COMP_CWORD = $i + 1
                break
            } elseif ($cursorPosition -lt $extent.StartColumnNumber) {
                $previousWord = $commandAst.CommandElements[$i - 1].Extent.Text
                $COMP_CWORD = $i
                break
            } elseif ($i -eq $commandAst.CommandElements.Count - 1 -and $cursorPosition -gt $extent.EndColumnNumber) {
                $previousWord = $extent.Text
                $COMP_CWORD = $i + 1
                break
            }
        }

        $currentExtent = $commandAst.CommandElements[$COMP_CWORD].Extent
        $previousExtent = $commandAst.CommandElements[$COMP_CWORD - 1].Extent
        if ($currentExtent.Text -like "/*" -and $currentExtent.StartColumnNumber -eq $previousExtent.EndColumnNumber) {
            $COMP_LINE = $COMP_LINE -replace "$($previousExtent.Text)$($currentExtent.Text)", $wordToComplete
            $COMP_WORDS = $COMP_WORDS -replace "$($previousExtent.Text) '$($currentExtent.Text)'", $wordToComplete
            $previousWord = $commandAst.CommandElements[$COMP_CWORD - 2].Extent.Text
            $COMP_CWORD -= 1
        }

        $command = $commandAst.CommandElements[0].Value
        $bashCompletion = ". /usr/share/bash-completion/bash_completion 2> /dev/null"
        $commandCompletion = ". /usr/share/bash-completion/completions/$command 2> /dev/null"
        $COMPINPUT = "COMP_LINE=$COMP_LINE; COMP_WORDS=$COMP_WORDS; COMP_CWORD=$COMP_CWORD; COMP_POINT=$cursorPosition"
        $COMPGEN = "bind `"set completion-ignore-case on`" 2> /dev/null; $F `"$command`" `"$wordToComplete`" `"$previousWord`" 2> /dev/null"
        $COMPREPLY = "IFS=`$'\n'; echo `"`${COMPREPLY[*]}`""
        $commandLine = "$bashCompletion; $commandCompletion; $COMPINPUT; $COMPGEN; $COMPREPLY" -split ' '

        $previousCompletionText = ""
        (wsl.exe $commandLine) -split '\n' |
                Sort-Object -Unique -CaseSensitive |
                ForEach-Object {
                    if ($wordToComplete -match "(.*=).*") {
                        $completionText = Format_WslArgument ($Matches[1] + $_) $true
                        $listItemText = $_
                    } else {
                        $completionText = Format_WslArgument $_ $true
                        $listItemText = $completionText
                    }

                    if ($completionText -eq $previousCompletionText) {
                        $listItemText += ' '
                    }

                    $previousCompletionText = $completionText
                    [System.Management.Automation.CompletionResult]::new($completionText, $listItemText, 'ParameterName', $completionText)
                }
    }
}

function global:Format_WslArgument([string]$arg, [bool]$interactive) {
    if ($interactive -and $arg.Contains(" ")) {
        return "'$arg'"
    } else {
        return ($arg -replace " ", "\ ") -replace "([()|])", ('\$1', '`$1')[$interactive]
    }
}
###< I now have some bash. ###

function connect {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$pshost
    )
    $credential = Get-Credential
    $options = New-PSSessionOption -SkipCACheck -SkipCNCheck
    $session = New-PSSession -Credential $cred $pshost -UseSSL -SessionOption $options -Authentication Default
    copy_profile $session
    Enter-PSSession $session
}

function copy_profile() {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true, Position=0)]
        [System.Management.Automation.Runspaces.PSSession]$session
    )
    if (!(Test-Path $profile)) {
        return
    }
    $result = Invoke-Command -Session $session -ScriptBlock { 
        cd ~ 
        gl 
        if (!(Test-Path "Documents\WindowsPowerShell")) {
            mkdir "Documents\WindowsPowerShell" 
        }
    }
    $home_dir = $result.path.trim()
    copy-item -Path $profile -ToSession $session -Destination "$home_dir\Documents\WindowsPowerShell\profile.ps1"
    Invoke-Command -Session $session -ScriptBlock { 
        cd ~
        $env:remote = "true"
        . "Documents\WindowsPowerShell\profile.ps1"  
    }
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
        $pythons = [ordered]@{
            "39" = "c:\python39\python.exe";
            "38" = "c:\python38\python.exe";
            "37" = "c:\python37\python.exe";
            "36" = "c:\python36\python.exe" }
        foreach ($i in $pythons.getEnumerator()) {
            $python = $i.value
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
    if ($env:remote) {
        $main_color = [ConsoleColor]::Blue
    }
    else {
        $main_color = [ConsoleColor]::DarkGreen
    }
    try {
        $output = git status --porcelain --branch 2>$null | Out-String 
    }
    catch {
        $output = ""
    }
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
        if ($virtualenv.endswith(".wenv")) {
            $virtualenv = Split-Path $virtualenv -Parent
        }
        
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
    $environment_type = "posh"
    if (!($env:remote)) {
        if ($psversiontable.psversion.major -gt 5) {
            $environment_type = "core"
        }
    }
    elseif ($env:remote -eq "ssh") {
        $environment_type = "ssh"
    }
    else {
        $environment_type = "winrm"
    }
    $z = $pieces2.Add(($environment_type, [ConsoleColor]::DarkRed))
    $length2 += $environment_type.length + 2
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
    Write-Host "┏" -ForegroundColor $main_color -NoNewline
    foreach ($x in $pieces1) {
        $st = $x[0];
        $color = $x[1];
        Write-Host "━━" -ForegroundColor $main_color -NoNewline
        Write-Host " $st " -ForegroundColor $color -NoNewline
    }
    if ($padding1) {
        Write-Host $padding1 -ForegroundColor $main_color -NoNewline
    }
    Write-Host "━┓" -ForegroundColor $main_color
    Write-Host "┣" -ForegroundColor $main_color -NoNewline
    foreach ($x in $pieces2) {
        $st = $x[0];
        $color = $x[1];
        Write-Host "━━" -ForegroundColor $main_color -NoNewline
        Write-Host " $st " -ForegroundColor $color -NoNewline
    }
    if ($padding2) {
        Write-Host $padding2 -ForegroundColor $main_color -NoNewline
    }
    Write-Host "━┛" -ForegroundColor $main_color
    Write-Host "┗ " -nonewline -ForegroundColor $main_color
    Write-Host "➤" -foregroundcolor white -nonewline
    if ($env:remote -and $env:remote -ne "ssh") {
        $bad_prompt = get_fqdn
        $bad_prompt_length = $bad_prompt.length + 4
        $tail = ("`b" * $bad_prompt_length) + (" " * $bad_prompt_length) + ("`b" * $bad_prompt_length) + " "
        return $tail
    }
    return " "
}

function connect_exchange {
    Import-Module exchangeonlinemanagement
    Connect-ExchangeOnline -ShowProgress:$true 
}

Set-Alias vi vim

# uncomment line for fleeting_fling if you have copied fleeting_fling.psm1 module into path:
# C:\Users\wthompson\Documents\WindowsPowerShell\Modules\fleeting_fling\fleeting_fling.psm1
# see README in Moduless dir of dotfiles
#
# Import-Module fleeting_fling

[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12

try {
    Import-Module DirColors -erroraction silentlycontinue
    setup_dircolors
}
catch {
    Write-Host "Please run Install-Module dircolors"
}
try {
    ipmo DockerCompletion -erroraction silentlycontinue
}
catch {
   Write-Host "Please run install-module dockercompletion"
}

Set-PSReadlineKeyHandler -Key Ctrl+d -Function DeleteCharOrExit

# SIG # Begin signature block
# MIITjwYJKoZIhvcNAQcCoIITgDCCE3wCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQU9qhY2kdWuqp4/RvaulK4wrdv
# bXegghDGMIIFRDCCBCygAwIBAgIRAPObRmxze0JQ5eGP2ElORJ8wDQYJKoZIhvcN
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
# SfLmEsjeyQnAeHUBJTAwggWBMIIEaaADAgECAhA5ckQ6+SK3UdfTbBDdMTWVMA0G
# CSqGSIb3DQEBDAUAMHsxCzAJBgNVBAYTAkdCMRswGQYDVQQIDBJHcmVhdGVyIE1h
# bmNoZXN0ZXIxEDAOBgNVBAcMB1NhbGZvcmQxGjAYBgNVBAoMEUNvbW9kbyBDQSBM
# aW1pdGVkMSEwHwYDVQQDDBhBQUEgQ2VydGlmaWNhdGUgU2VydmljZXMwHhcNMTkw
# MzEyMDAwMDAwWhcNMjgxMjMxMjM1OTU5WjCBiDELMAkGA1UEBhMCVVMxEzARBgNV
# BAgTCk5ldyBKZXJzZXkxFDASBgNVBAcTC0plcnNleSBDaXR5MR4wHAYDVQQKExVU
# aGUgVVNFUlRSVVNUIE5ldHdvcmsxLjAsBgNVBAMTJVVTRVJUcnVzdCBSU0EgQ2Vy
# dGlmaWNhdGlvbiBBdXRob3JpdHkwggIiMA0GCSqGSIb3DQEBAQUAA4ICDwAwggIK
# AoICAQCAEmUXNg7D2wiz0KxXDXbtzSfTTK1Qg2HiqiBNCS1kCdzOiZ/MPans9s/B
# 3PHTsdZ7NygRK0faOca8Ohm0X6a9fZ2jY0K2dvKpOyuR+OJv0OwWIJAJPuLodMkY
# tJHUYmTbf6MG8YgYapAiPLz+E/CHFHv25B+O1ORRxhFnRghRy4YUVD+8M/5+bJz/
# Fp0YvVGONaanZshyZ9shZrHUm3gDwFA66Mzw3LyeTP6vBZY1H1dat//O+T23LLb2
# VN3I5xI6Ta5MirdcmrS3ID3KfyI0rn47aGYBROcBTkZTmzNg95S+UzeQc0PzMsNT
# 79uq/nROacdrjGCT3sTHDN/hMq7MkztReJVni+49Vv4M0GkPGw/zJSZrM233bkf6
# c0Plfg6lZrEpfDKEY1WJxA3Bk1QwGROs0303p+tdOmw1XNtB1xLaqUkL39iAigmT
# Yo61Zs8liM2EuLE/pDkP2QKe6xJMlXzzawWpXhaDzLhn4ugTncxbgtNMs+1b/97l
# c6wjOy0AvzVVdAlJ2ElYGn+SNuZRkg7zJn0cTRe8yexDJtC/QV9AqURE9JnnV4ee
# UB9XVKg+/XRjL7FQZQnmWEIuQxpMtPAlR1n6BB6T1CZGSlCBst6+eLf8ZxXhyVeE
# Hg9j1uliutZfVS7qXMYoCAQlObgOK6nyTJccBz8NUvXt7y+CDwIDAQABo4HyMIHv
# MB8GA1UdIwQYMBaAFKARCiM+lvEH7OKvKe+CpX/QMKS0MB0GA1UdDgQWBBRTeb9a
# qitKz1SA4dibwJ3ysgNmyzAOBgNVHQ8BAf8EBAMCAYYwDwYDVR0TAQH/BAUwAwEB
# /zARBgNVHSAECjAIMAYGBFUdIAAwQwYDVR0fBDwwOjA4oDagNIYyaHR0cDovL2Ny
# bC5jb21vZG9jYS5jb20vQUFBQ2VydGlmaWNhdGVTZXJ2aWNlcy5jcmwwNAYIKwYB
# BQUHAQEEKDAmMCQGCCsGAQUFBzABhhhodHRwOi8vb2NzcC5jb21vZG9jYS5jb20w
# DQYJKoZIhvcNAQEMBQADggEBABiHUdx0IT2ciuAntzPQLszs8ObLXhHeIm+bdY6e
# cv7k1v6qH5yWLe8DSn6u9I1vcjxDO8A/67jfXKqpxq7y/Njuo3tD9oY2fBTgzfT3
# P/7euLSK8JGW/v1DZH79zNIBoX19+BkZyUIrE79Yi7qkomYEdoiRTgyJFM6iTcky
# s7roFBq8cfFb8EELmAAKIgMQ5Qyx+c2SNxntO/HkOrb5RRMmda+7qu8/e3c70sQC
# kT0ZANMXXDnbP3sYDUXNk4WWL13fWRZPP1G91UUYP+1KjugGYXQjFrUNUHMnREd/
# EF2JKmuFMRTE6KlqTIC8anjPuH+OdnKZDJ3+15EIFqGjX5UwggX1MIID3aADAgEC
# AhAdokgwb5smGNCC4JZ9M9NqMA0GCSqGSIb3DQEBDAUAMIGIMQswCQYDVQQGEwJV
# UzETMBEGA1UECBMKTmV3IEplcnNleTEUMBIGA1UEBxMLSmVyc2V5IENpdHkxHjAc
# BgNVBAoTFVRoZSBVU0VSVFJVU1QgTmV0d29yazEuMCwGA1UEAxMlVVNFUlRydXN0
# IFJTQSBDZXJ0aWZpY2F0aW9uIEF1dGhvcml0eTAeFw0xODExMDIwMDAwMDBaFw0z
# MDEyMzEyMzU5NTlaMHwxCzAJBgNVBAYTAkdCMRswGQYDVQQIExJHcmVhdGVyIE1h
# bmNoZXN0ZXIxEDAOBgNVBAcTB1NhbGZvcmQxGDAWBgNVBAoTD1NlY3RpZ28gTGlt
# aXRlZDEkMCIGA1UEAxMbU2VjdGlnbyBSU0EgQ29kZSBTaWduaW5nIENBMIIBIjAN
# BgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAhiKNMoV6GJ9J8JYvYwgeLdx8nxTP
# 4ya2JWYpQIZURnQxYsUQ7bKHJ6aZy5UwwFb1pHXGqQ5QYqVRkRBq4Etirv3w+Bis
# p//uLjMg+gwZiahse60Aw2Gh3GllbR9uJ5bXl1GGpvQn5Xxqi5UeW2DVftcWkpwA
# L2j3l+1qcr44O2Pej79uTEFdEiAIWeg5zY/S1s8GtFcFtk6hPldrH5i8xGLWGwuN
# x2YbSp+dgcRyQLXiX+8LRf+jzhemLVWwt7C8VGqdvI1WU8bwunlQSSz3A7n+L2U1
# 8iLqLAevRtn5RhzcjHxxKPP+p8YU3VWRbooRDd8GJJV9D6ehfDrahjVh0wIDAQAB
# o4IBZDCCAWAwHwYDVR0jBBgwFoAUU3m/WqorSs9UgOHYm8Cd8rIDZsswHQYDVR0O
# BBYEFA7hOqhTOjHVir7Bu61nGgOFrTQOMA4GA1UdDwEB/wQEAwIBhjASBgNVHRMB
# Af8ECDAGAQH/AgEAMB0GA1UdJQQWMBQGCCsGAQUFBwMDBggrBgEFBQcDCDARBgNV
# HSAECjAIMAYGBFUdIAAwUAYDVR0fBEkwRzBFoEOgQYY/aHR0cDovL2NybC51c2Vy
# dHJ1c3QuY29tL1VTRVJUcnVzdFJTQUNlcnRpZmljYXRpb25BdXRob3JpdHkuY3Js
# MHYGCCsGAQUFBwEBBGowaDA/BggrBgEFBQcwAoYzaHR0cDovL2NydC51c2VydHJ1
# c3QuY29tL1VTRVJUcnVzdFJTQUFkZFRydXN0Q0EuY3J0MCUGCCsGAQUFBzABhhlo
# dHRwOi8vb2NzcC51c2VydHJ1c3QuY29tMA0GCSqGSIb3DQEBDAUAA4ICAQBNY1Dt
# RzRKYaTb3moqjJvxAAAeHWJ7Otcywvaz4GOz+2EAiJobbRAHBE++uOqJeCLrD0bs
# 80ZeQEaJEvQLd1qcKkE6/Nb06+f3FZUzw6GDKLfeL+SU94Uzgy1KQEi/msJPSrGP
# JPSzgTfTt2SwpiNqWWhSQl//BOvhdGV5CPWpk95rcUCZlrp48bnI4sMIFrGrY1rI
# FYBtdF5KdX6luMNstc/fSnmHXMdATWM19jDTz7UKDgsEf6BLrrujpdCEAJM+U100
# pQA1aWy+nyAlEA0Z+1CQYb45j3qOTfafDh7+B1ESZoMmGUiVzkrJwX/zOgWb+W/f
# iH/AI57SHkN6RTHBnE2p8FmyWRnoao0pBAJ3fEtLzXC+OrJVWng+vLtvAxAldxU0
# ivk2zEOS5LpP8WKTKCVXKftRGcehJUBqhFfGsp2xvBwK2nxnfn0u6ShMGH7EezFB
# cZpLKewLPVdQ0srd/Z4FUeVEeN0B3rF1mA1UJP3wTuPi+IO9crrLPTru8F4Xkmht
# yGH5pvEqCgulufSe7pgyBYWe6/mDKdPGLH29OncuizdCoGqC7TtKqpQQpOEN+BfF
# tlp5MxiS47V1+KHpjgolHuQe8Z9ahyP/n6RRnvs5gBHN27XEp6iAb+VT1ODjosLS
# Wxr6MiYtaldwHDykWC6j81tLB9wyWfOHpxptWDGCAjMwggIvAgEBMIGRMHwxCzAJ
# BgNVBAYTAkdCMRswGQYDVQQIExJHcmVhdGVyIE1hbmNoZXN0ZXIxEDAOBgNVBAcT
# B1NhbGZvcmQxGDAWBgNVBAoTD1NlY3RpZ28gTGltaXRlZDEkMCIGA1UEAxMbU2Vj
# dGlnbyBSU0EgQ29kZSBTaWduaW5nIENBAhEA85tGbHN7QlDl4Y/YSU5EnzAJBgUr
# DgMCGgUAoHgwGAYKKwYBBAGCNwIBDDEKMAigAoAAoQKAADAZBgkqhkiG9w0BCQMx
# DAYKKwYBBAGCNwIBBDAcBgorBgEEAYI3AgELMQ4wDAYKKwYBBAGCNwIBFTAjBgkq
# hkiG9w0BCQQxFgQUgKebElwp6NZvmFu9Q8ZFv6HpdZMwDQYJKoZIhvcNAQEBBQAE
# ggEADf9kaqx8qcs2mP5HQxbdHkCkgBydWwQPwe4uDTJOhNz05ZNu0oqo1+MmXYmw
# NMbCfyJ+cl0IrDxIftvrVNH2r2JiLTGHtNKMzFb7Ksrh1+Qc1vASNXUtwct2OrpJ
# oHPpl55VHNTNlASwcf+vgJdcejLAXaBOCeRk1rW5dMStBreWVh9x+6ERddD6SbtB
# FYuyxy2R/utjTgSOT0xPS0Feyy8SZcmOWVQIhGGNXLjvx3tZuca8oJbsEg/ZAcw0
# XLo/ixjKn0GvcT0RO86mJTmGj24Rl8B4xZ5PBKCnJsSO6QX+BZWhPukeohAaZ3Xn
# Ov1dMmZ8YiJmz1QQ2yUARnHhWQ==
# SIG # End signature block
