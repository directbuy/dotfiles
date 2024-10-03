<#
    .synopsis
    registers typical bash functions to run under the default wsl distro
    if wsl is present on the system.

    .description
    registers awk, emacs, grep, head, less, ls, man, sed, seq, ssh, tail, and touch
    to run via wsl.exe instead of running via cygwin or from the default
    powershell aliases (e.g., powershell aliases ls as dir).  The motivation
    behind this is that it can often be confusing in powershell when you use
    `ls -la` only to have the command fail because `-la` is not a recognized
    parameter on `Get-Item` / `dir`

#>
function bash_commands_via_wsl {
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
            (wsl.exe $commandLine) -split '\n' `
                | Sort-Object -Unique -CaseSensitive `
                | ForEach-Object {
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
}


function global:Format_WslArgument([string]$arg, [bool]$interactive) {
    if ($interactive -and $arg.Contains(" ")) {
        return "'$arg'"
    } else {
        return ($arg -replace " ", "\ ") -replace "([()|])", ('\$1', '`$1')[$interactive]
    }
}


<#
    .synopsis
    the connect cmdlet allows a user to connect to a remote windows system
    using the winrm protocol

    .parameter pshost
    the fqdn or the ip address of the remote windows server

    .parameter copy_profile
    if specified, this switch will copy your local profile to the remote server
    so that you have a consistent set of modules available on all servers

#>
function connect {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$pshost,
        [switch]$copy_profile
    )
    $credential = Get-Credential
    $options = New-PSSessionOption -SkipCACheck -SkipCNCheck
    $session = New-PSSession -Credential $cred $pshost -UseSSL -SessionOption $options -Authentication Default
    if ($copy_profile) {
        copy_profile $session
    }
    Enter-PSSession $session
}


<#
    .synopsis
    copies a local profile to a remote powershell session.

    .description
    used by the connect cmdlet so that you can connect to a system
    and  copy your local profile up to the server all in one go

    .example
    PS> $session = Get-PsSession -Id 1
    PS> copy_profile $session
#>
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
        $env:remote = "winrm"
        . "Documents\WindowsPowerShell\profile.ps1"  
    }
}


<#
    .synopsis
    dircolors is a powershell module available in psgallery.  It is used to
    add color-coding to the output of the `dir` command.

    .description
    this cmdlet is not meant to be called stand-alone.  we define it to
    help modularize the startup of the profile.
#>
function setup_dircolors() {
    $dircolors = "C:\u\dotfiles\zsh\.dircolors"
    if ((Test-Path $dircolors) -and (!(Test-Path "${env:HOMEDRIVE}${env:HOMEPATH}\.dircolors"))) {
        copy $dircolors "${env:HOMEDRIVE}${env:HOMEPATH}"
        Update-DirColors $dircolors
    }
}


<#
    .synopsis
    venv is a cmdlet that is used to setup a virtual environment for a
    python project.  e.g., if you clone upholstery and then wanted to
    setup the virtual environment, you could use this cmdlet to do the
    setup of the virtual environment.

    .description
    this cmdlet favors later pythons over older pythons.  If a specific
    python is needed, do not use this cmdlet.  this cmdlet will
    install any dependencies noted in the `requirements.txt` file as well
    as running the setup.py file.  this cmdlet also installs setuptools
    and wheel by default.
#>
function venv {
    if (!(Test-Path ".wenv")) {
        $pythons = [ordered]@{
            "39" = "c:\python39\python.exe";
            "38" = "c:\python38\python.exe";
            "37" = "c:\python37\python.exe";
            "36" = "c:\python36\python.exe"
        }
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


<#
    .synopsis
    if you are in a directory for a python project and want to
    activate the virtual environment, use this cmdlet as a quick alias
    to activate the venv.

    .description
    this cmdlet favors later pythons over older pythons.  If a specific
    python is needed, do not use this cmdlet.  this cmdlet will
    install any dependencies noted in the `requirements.txt` file as well
    as running the setup.py file.  this cmdlet also installs setuptools
    and wheel by default.
#>
function djact() {
    if ((Test-Path ".wenv") -and (Test-Path ".\.wenv\scripts\activate.ps1")) {
        . ".\.wenv\scripts\activate.ps1" 
    }
    else {
        $name = ([io.fileinfo]"$pwd").basename
        workon $name
    }
}


<#
    .synopsis
    alias to manage.py, useful for running django commands
#>
function dj() {
    if (!(Test-Path .\manage.py)) {
        Write-Host "no django found here"
        return
    }
    &python manage.py @args
}


<#
    .synopsis
    alias to start up shell_plus in django
#>
function djsp() {
    dj shell_plus --quiet-load
}


<#
    .synopsis
    shows us the weather in a nice ascii format using wttr.in

    .parameter city
    the name of the city for which to show the weather.  defaults to
    chicago.

    .example
    PS> weather -city cleveland

    .example
    PS> weather -city "merrillville, in"

#>
function weather {
    param(
        [string]$city="Chicago"
    )
    $weather = (Invoke-WebRequest "https://wttr.in/${city}" -UserAgent "curl").content
    $weather = $weather -split "`n"
    for ($x = 0; $x -lt 17; ++$x) {
        Write-Host $weather[$x]
    }
}

<#
    .cdm / .cdo
    change to our working code in U directory
#>
function cu {
    param([string]$subdir="m")
    $dirName = "Maintenance"
    if ($subdir -eq "o")
    { $dirName = "OAKAPI" }
    if ($subdir -eq "t")
    { $dirName = "TMS" }
    cd c:/u/$dirName
}

function tms {
    $devenvPath = "C:\Program Files\Microsoft Visual Studio\2022\Enterprise\Common7\IDE\devenv.exe"
    $tmsPath = "C:\u\TMS\TMS.sln"
    $tmsapiPath = "C:\u\TMSApi\TMSApi.sln"

    & $devenvPath $tmsPath
    & $devenvPath $tmsapiPath
}

function dashboard {
    $devenvPath = "C:\Program Files\Microsoft Visual Studio\2022\Enterprise\Common7\IDE\devenv.exe"
    $maintenancePath = "C:\u\Maintenance\Maintenance.sln"
    $oakapiPath = "C:\u\OAKApi\OAKApi.sln"

    & $devenvPath $maintenancePath
    & $devenvPath $oakapiPath
}

function nodeclean {
    $nodeModulesDir = "C:/u/Maintenance/node_modules"
    $bundlesDir = "C:/u/Maintenance/wwwroot/js/bundles"

    if (test-path $nodeModulesDir) {
        Remove-Item -LiteralPath "C:/u/Maintenance/node_modules" -Force -Recurse 
    }
    if (test-path $bundlesDir) {
        Remove-Item -LiteralPath "C:/u/Maintenance/wwwroot/js/bundles" -Force -Recurse
    }
    cd "c:/u/Maintenance" -and npm install -and npm run build
}

function restart_site() {
    $userCredential = Get-Credential;
    $serverName = Read-Host "Server name";
    Invoke-Command -Computername $serverName -credential $userCredential -Scriptblock {
        (Import-Module WebAdministration);
        $websiteName = Read-Host "Website name";
        Stop-Website -Name $websiteName;
        Start-Website -Name $websiteName;
    }
}

function stop_site() {
    $userCredential = Get-Credential;
    $serverName = Read-Host "Server name";
    Invoke-Command -Computername $serverName -credential $userCredential -Scriptblock {
        (Import-Module WebAdministration)
        $websiteName = Read-Host "website name";
        Stop-Website -Name $websiteName;
    }
}

function oakapi_sqlscripts {
    $server = "USASQL01\TSTEST"
    $username = "dashboard"
    $password = "dashboard"

    Write-Output "RUNNING SQL FILES FOR OAKTS_TEST"
    $files = Get-ChildItem "C:\u\OAKApi\API\sql_scripts\OAKTS scripts" -Filter *.sql 
    foreach ($file in $files) {
        Write-Output "File: " $file.FullName
        invoke-sqlcmd -InputFile $file.FullName -ServerInstance $server -username $username -Password $password -Database "OAKTS_TEST"   
    }
    Write-Output "RUNNING SQL FILES FOR OAKTS_DOCS"
    $files = Get-ChildItem "C:\u\OAKApi\API\sql_scripts\OAKTS_DOCS" -Filter *.sql
    foreach ($file in $files) {
        Write-Output "File: " $file.FullName
        invoke-sqlcmd -InputFile $file.FullName -ServerInstance $server -username $username -Password $password -Database "OAKTS_DOCS"
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
    $computer = $env:COMPUTERNAME.tolower()
    $user = $env:USERNAME.tolower()
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


<#
    .synopsis
    simple cmdlet that connects you to exchange 365 to run cmdlets
#>
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
bash_commands_via_wsl
Set-PSReadlineKeyHandler -Key Ctrl+d -Function DeleteCharOrExit


#PLEASE READ and follow steps below
#1. ENTER YOUR EMAIL ADDRESS HERE:
$myemailaddress = "johndoe@contoso.com"
#2. COPY ALL THE SCRIPTS TO YOUR EXISTING PROFILE
#3. Reload your Posh and run myo365tools function
#4. Enter 1 in the menu and press enter to Connect to Services ( you must have global admin role to connect to all 3 services, msol,exchangeonline,sharepoint(spo) )
#5 once connected. run myo365tools function again to start using the tool

###START MYO365TOOLS###
function myo365tools()
{
cls

Write-Host "MY O365 TOOLS Menu" -ForegroundColor Yellow
Write-Host "1  - Connect to MSOL $global:statusmsol,EXOPS $global:statusmsol and SPO $global:statusspo" -ForegroundColor Green
Write-Host "2  - User Search and License Management Tool" -ForegroundColor Green
Write-Host "3  - Mailbox Permissions" -ForegroundColor Green
Write-Host "4  - Distribution Group Management" -ForegroundColor Green
Write-Host "5  - OneDrive Access Management Tool" -ForegroundColor Green
Write-Host "Enter the choice number or type " -NoNewline
Write-Host " [quit] " -ForegroundColor Yellow -NoNewline
Write-Host "to exit: " -NoNewline

$choice = Read-Host
    switch  ($choice)
    {

     'quit' {
        cls
        return

            }
     '1' {
        cls
        Write-Host "Connecting to MSOL Service..."
        Connect-MsolService
        $global:mytenantnamefinal = $null;

        $mytenantinfo = (Get-MsolDomain | Where-Object {$_.isInitial}).name
        $mytenantname = $mytenantinfo.split('.');
        $global:mytenantnamefinal = $mytenantname[0]
        connect_exchange_online
        connect_spo
        check_connections_status

         }
     '2' {
        cls
        msol_management
          }
     '3' {
        cls
        exchange_management
         }

     '4' {
        cls
        exchange_group_management
         }

     '5' {
        cls
        onedrive_management_tool
         }

     }
}

#start exchange group management#
function exchange_group_management()
{
cls
Write-Host "*****EXCHANGE GROUP MANAGEMENT TOOL*****" -ForegroundColor Green
Write-Host "1  - Search Group Name " -ForegroundColor Green
Write-Host "2  - Add Member to Online Group " -ForegroundColor Green
Write-Host "3  - Remove Member from Online Group" -ForegroundColor Green
Write-Host "4  - View Members of a Group" -ForegroundColor Green

Write-Host "Enter the choice number or type " -NoNewline
Write-Host " [quit] " -ForegroundColor Yellow -NoNewline
Write-Host "to go back to previous menu: " -NoNewline

$exchange_choice = Read-Host
    switch  ($exchange_choice)
    {

     'quit' {

        return myo365tools

            }
     '1' {

        cls
        exchange_group_finder


         }
     '2' {
        cls
        add_to_exchange_group

          }
     '3' {
        cls
        remove_from_exchange_group
         }

     '4' {
        cls
        view_distro_group_members
         }


     }
}

function exchange_group_finder()
{
Write-Host "*****EXCHANGE GROUP FINDER*****" -ForegroundColor Green
Write-Host "Enter name or part of the group name or type" -NoNewline
Write-Host " [quit] " -ForegroundColor Yellow -NoNewline
Write-Host "to go back to previous menu : " -NoNewline

    $mailgroupsearch = Read-Host
    if ($mailgroupsearch -eq 'quit' -or $mailgroupsearch -eq '')
    {
    return exchange_group_management
    }

   if (!(Get-Group -Anr $mailgroupsearch | select Name))
   {
   Write-Host "No group found with that name. Please try again." -ForegroundColor Red
   exchange_group_finder
   }
   else
   {
   Get-Group -Anr $mailgroupsearch | select Name,WindowsEmailAddress |  Format-Table

   exchange_group_finder
   }
}

function add_to_exchange_group()
{
Write-Host "*****ADD MEMBER TO ONLINE GROUP*****" -ForegroundColor Green
Write-Host "Enter the employee email address or type" -NoNewline
Write-Host " [quit] " -ForegroundColor Yellow -NoNewline
Write-Host "to go back to previous menu : " -NoNewline

    $emailaddress = Read-Host
    if ($emailaddress -eq 'quit' -or $emailaddress -eq '')
    {
    return exchange_group_management
    }

    else
    {

    $result = Get-MsolUser -userprincipalname $emailaddress -ErrorAction 0
        if (!$result)
        {
        Write-Host "Nothing found. Please try again."

        return add_to_exchange_group
        }
    Write-Host "***USER INFORMATION*** :" -ForegroundColor Yellow
    Get-MsolUser -UserPrincipalName $emailaddress | Select DisplayName,UserPrincipalName | Format-Table

    Write-Host "Enter the distribution group email address you want this user to be added to or type" -NoNewline
    Write-Host " [quit] " -ForegroundColor Yellow -NoNewline
    Write-Host "to cancel: " -NoNewline
    $exchange_groupname = Read-Host

    if ($exchange_groupname -eq 'quit' -or $exchange_groupname -eq '')
    {
    cls
    return add_to_exchange_group
    }


    if (!(Get-DistributionGroup -identity $exchange_groupname -ErrorAction 0))
    {
    Write-Host "No distribution group found with that name. Please try again." -ForegroundColor Red
    Read-Host -Prompt "Press Enter to continue"
    cls
    add_to_exchange_group
    }
    Write-Host "***DISTRIBUTION GROUP INFORMATION***" -ForegroundColor Yellow
    Get-DistributionGroup -identity $exchange_groupname | Format-Table

    Write-Host "Add" $emailaddress "to group" $exchange_groupname"? Y/N: " -ForegroundColor Red -NoNewline
    $addconfirm= Read-Host
        if ($addconfirm-eq 'Y')
        {
        Add-DistributionGroupMember -identity $exchange_groupname -Member $emailaddress
        Write-Host "***$exchange_groupname GROUP MEMBERS***" -ForegroundColor Yellow
        Get-DistributionGroupMember -identity $exchange_groupname | Select Name,PrimarySMTPAddress | Format-Table
        Write-Host "Completed!"
        Read-Host -Prompt "Press Enter to continue"
        cls
        add_to_exchange_group
        }
        else
        {
        cls
        return add_to_exchange_group
        }
  }
}

function remove_from_exchange_group()
{
Write-Host "*****REMOVE MEMBER FROM ONLINE GROUP*****" -ForegroundColor Green
Write-Host "Enter the group email address or type" -NoNewline
Write-Host " [quit] " -ForegroundColor Yellow -NoNewline
Write-Host "to go back to previous menu : " -NoNewline


    $exchange_groupname = Read-Host

    if ($exchange_groupname -eq 'quit' -or $exchange_groupname -eq '')
    {

    return exchange_group_management
    }


    if (!(Get-DistributionGroup -identity $exchange_groupname -ErrorAction 0))
    {
    Write-Host "No distribution group found with that name. Please try again." -ForegroundColor Red
    Read-Host -Prompt "Press Enter to continue"
    cls
    return remove_from_exchange_group
    }
    Write-Host "***DISTRIBUTION GROUP MEMBERS***:" -ForegroundColor Yellow
    Write-Host "for Account : $exchange_groupname" -ForegroundColor Yellow

    Get-DistributionGroupMember -identity $exchange_groupname | Select Name,PrimarySMTPAddress | Format-Table


    Write-Host "Enter the email address you want to remove or type" -NoNewline
    Write-Host " [quit] " -ForegroundColor Yellow -NoNewline
    Write-Host "to cancel: " -NoNewline


    $emailaddress = Read-Host
    if ($emailaddress -eq 'quit' -or $emailaddress -eq '')
    {
    cls
    return exchange_group_management
    }

    else
    {

    $result = Get-MsolUser -userprincipalname $emailaddress -ErrorAction 0
        if (!$result)
        {
        Write-Host "Email not found. Please verify email and start over."

        return remove_from_exchange_group
        }


    Write-Host "***USER INFORMATION***" -ForegroundColor Yellow
    Get-MsolUser -UserPrincipalName $emailaddress | Select DisplayName,UserPrincipalName | Format-Table


    Write-Host "REMOVE" $emailaddress "from group" $exchange_groupname"? Y/N: " -ForegroundColor Red -NoNewline
    $removeconfirm= Read-Host
        if ($removeconfirm-eq 'Y')
        {
        Remove-DistributionGroupMember -identity $exchange_groupname -Member $emailaddress -confirm:$false
        Write-Host "***DISTRIBUTION GROUP MEMBERS***:" -ForegroundColor Yellow
        Write-Host "for Account : $exchange_groupname" -ForegroundColor Yellow
        Get-DistributionGroupMember -identity $exchange_groupname | Select Name,PrimarySMTPAddress | Format-Table
        Write-Host "Done!"
        Read-Host -Prompt "Press Enter to continue"
        cls
        remove_from_exchange_group
        }
        else
        {
        return remove_from_exchange_group
        }
  }
}

function view_distro_group_members()
{
Write-Host "*****VIEW GROUP MEMBERS*****" -ForegroundColor Green
Write-Host "Enter email address of the group or type" -NoNewline
Write-Host " [quit] " -ForegroundColor Yellow -NoNewline
Write-Host "to go back to previous menu : " -NoNewline

    $mailgroupsearch = Read-Host
    if ($mailgroupsearch -eq 'quit' -or $mailgroupsearch -eq '')
    {
    return exchange_group_management
    }

   if (!(Get-DistributionGroup -identity $mailgroupsearch -ErrorAction 0 ))
   {
   Write-Host "No group found with that name. Please try again." -ForegroundColor Red
   view_distro_group_members
   }
   else
   {
   Write-Host "***DISTRIBUTION GROUP MEMBERS*** " -ForegroundColor Yellow
   Get-DistributionGroupMember -identity $mailgroupsearch | select Name,PrimarySMTPAddress |  Format-Table

   view_distro_group_members
   }
}
#end of exchange group management#

function msol_management()
{
cls
Write-Host "*****User Search and License Management Tool*****" -ForegroundColor Yellow
Write-Host "1  - Search User" -ForegroundColor Green
Write-Host "2  - List SKU Licenses" -ForegroundColor Green
Write-Host "3  - Manage User licenses" -ForegroundColor Green
Write-Host "4  - MFA Management" -ForegroundColor Green


Write-Host "Enter the choice number or type " -NoNewline
Write-Host " [quit] " -ForegroundColor Yellow -NoNewline
Write-Host "to go back to previous menu: " -NoNewline

$msol_choice = Read-Host
    switch  ($msol_choice)
    {

     'quit' {

        return myo365tools

            }
     '1' {

        cls
        search_msol_user


         }
     '2' {
        cls
        msol_sku

          }
     '3' {
        cls
        license_management
         }
     '4' {
        cls
        mfa_management
         }
     }
}

#start exchange management
function exchange_management()
{

cls
Write-Host "*****MAILBOX PERMISSIONS TOOL*****" -ForegroundColor Green
Write-Host "1  - View Mailbox permissions" -ForegroundColor Green
Write-Host "2  - Add Mailbox permissions " -ForegroundColor Green
Write-Host "3  - Remove Mailbox permissions" -ForegroundColor Green

Write-Host "Enter the choice number or type " -NoNewline
Write-Host " [quit] " -ForegroundColor Yellow -NoNewline
Write-Host "to go back to previous menu: " -NoNewline

$exchange_choice = Read-Host
    switch  ($exchange_choice)
    {

     'quit' {

        return myo365tools

            }
     '1' {

        cls
        view_mailboxpermission

         }

     '2' {
        cls
        add_fullaccess
         }

     '3' {
        cls
        remove_fullaccess
         }
     }
}
#end exchange_management


function license_management()
{

cls
Write-Host "*****USER LICENSE MANAGEMENT TOOL*****" -ForegroundColor Green
Write-Host "1  - Add License " -ForegroundColor Green
Write-Host "2  - Remove License " -ForegroundColor Green
Write-Host "3  - Upgrade/Change License " -ForegroundColor Green

Write-Host "Enter the choice number or type " -NoNewline
Write-Host " [quit] " -ForegroundColor Yellow -NoNewline
Write-Host "to go back to previous menu: " -NoNewline

$license_choice = Read-Host
    switch  ($license_choice)
    {

     'quit' {

        return msol_management

            }
     '1' {

        cls
        assign_license

         }

     '2' {
        cls
        remove_license
         }

     '3' {
        cls
        replace_license
         }

     }
}

function assign_license()
{
Write-Host "*****O365 LICENSE ASSIGNMENT TOOL*****" -ForegroundColor Green
Write-Host "Enter email address or userprincipalname or type" -NoNewline
Write-Host " [quit] " -ForegroundColor Yellow -NoNewline
Write-Host "to go back to previous menu: " -NoNewline
$uname = Read-Host
    if ($uname -eq 'quit' -or $uname -eq '')
    {
    return license_management
    }
    else
    {

    $result = Get-MsolUser -userprincipalname $uname -ErrorAction 0
        if (!$result)
        {
        Write-Host "Nothing found. Please try again."

        return assign_license
        }
        else
        {
        Write-Host "*** LICENSES ***" -ForegroundColor Yellow
        Get-MsolAccountSku | Format-Table AccountSkuID,ActiveUnits,ConsumedUnits
        Write-Host "*** USER INFO ***" -ForegroundColor Yellow
        Get-MsolUser -userprincipalname $uname |  Fl DisplayName,Licenses
        Write-Host "Enter the license pack to ASSIGN this user or type" -NoNewline
        Write-Host " [quit] " -ForegroundColor Yellow -NoNewline
        Write-Host "to cancel, ex " $global:mytenantnamefinal":ENTERPRISEPACK: " -NoNewline
        $licensepack = Read-Host
            if ($licensepack -eq 'quit' -or $licensepack -eq '')
            {
            #add script here to check if license exists in pool otherwise throw an error?
            return license_management
            }

            Write-Host "Do you want to ASSIGN $licensepack to $uname ?" -ForegroundColor Green
            Write-Host "Enter Y / N : " -ForegroundColor Yellow -NoNewline
            $confirmAssign = Read-Host
                if ($confirmAssign -eq 'Y')
                {
                enable_mfa $uname
                Set-MsolUserLicense -userprincipalname $uname -addlicenses "$licensepack"
                Get-MsolUser -userprincipalname $uname |  Fl DisplayName,Licenses
                Write-Host "Completed!"
                Write-Host "Please allow 5 mins to create the mailbox."
                Read-Host -Prompt "Press Enter to continue"

                }
        }
    }
cls
return assign_license
}

#upgrade/replace license start
function replace_license()
{
Write-Host "*****O365 LICENSE REPLACEMENT TOOL*****" -ForegroundColor Green
Write-Host "Enter email address or userprincipalname or type" -NoNewline
Write-Host " [quit] " -ForegroundColor Yellow -NoNewline
Write-Host "to go back to previous menu: " -NoNewline
$uname = Read-Host
    if ($uname -eq 'quit' -or $uname -eq '')
    {
    return license_management
    }
    else
    {

    $result = Get-MsolUser -userprincipalname $uname -ErrorAction 0
        if (!$result)
        {
        Write-Host "Nothing found. Please try again."

        return replace_license
        }
        else
        {

        Write-Host "*** USER INFO ***" -ForegroundColor Yellow
        Get-MsolUser -userprincipalname $uname |  Fl UserprincipalName,DisplayName,Licenses
        Write-Host "Enter the OLD license pack to REMOVE from this user or type" -NoNewline
        Write-Host " [quit] " -ForegroundColor Yellow -NoNewline
        Write-Host "to cancel, ex " $global:mytenantnamefinal":STANDARDPACK: " -NoNewline
        $oldlicensepack = Read-Host
            if ($oldlicensepack -eq 'quit' -or $oldlicensepack -eq '')
            {

            return replace_license
            }
        Write-Host "*** LICENSES ***" -ForegroundColor Yellow
        Get-MsolAccountSku | Format-Table AccountSkuID,ActiveUnits,ConsumedUnits
        Write-Host "Enter the NEW license pack to ASSIGN this user or type" -NoNewline
        Write-Host " [quit] " -ForegroundColor Yellow -NoNewline
        Write-Host "to cancel, ex " $global:mytenantnamefinal":ENTERPRISEPACK: " -NoNewline
        $newlicensepack = Read-Host
            if ($newlicensepack -eq 'quit' -or $newlicensepack -eq '')
            {

            return replace_license
            }

            Write-Host "Are you sure you want to REMOVE $oldlicensepack from $uname and REPLACE with $newlicensepack ?" -ForegroundColor Red
            Write-Host "Enter Y / N : " -ForegroundColor Yellow -NoNewline
            $confirmReplace = Read-Host
                if ($confirmReplace -eq 'Y')
                {
                Set-MsolUserLicense -Userprincipalname $uname -RemoveLicenses "$oldlicensepack"
                Set-MsolUserLicense -userprincipalname $uname -Addlicenses "$newlicensepack"
                Get-MsolUser -userprincipalname $uname |  Fl DisplayName,Licenses
                Write-Host "Completed!"
                Read-Host -Prompt "Press Enter to continue"

                }
        }
    }
cls
return replace_license

}
#upgrade/replace license end


function enable_mfa($email)
{
 $mfastate = Get-MsolUser -UserPrincipalName $email | select @{N='MFA State';E={($_.StrongAuthenticationRequirements.State)}}

    if ($mfastate -like '@{MFA State=}') #with Disabled status
    {
    Write-Host "MFA CHECK : MFA is not enabled for this account." -ForegroundColor Red
    Write-Host "Do you want to enable MFA for this account?"-ForegroundColor Green
    Write-Host "Enter Y / N : " -ForegroundColor Yellow -NoNewline
        $confirmMFA = Read-Host
        if ($confirmMFA -eq 'Y')
        {

        $st = New-Object -TypeName Microsoft.Online.Administration.StrongAuthenticationRequirement
        $st.RelyingParty = "*"
        $st.State = “Enabled”
        $sta = @($st)
        Set-MsolUser -UserPrincipalName $email -UsageLocation US -StrongAuthenticationRequirements $sta
        Write-Host "MFA STATUS : ENABLED" -ForegroundColor Green
        }

    }
    else
    {
    Write-Host "MFA STATUS : ALREADY ENABLED" -ForegroundColor Green
    }
}

#START activate mfa
function verify_activate_mfa()
{
cls
Write-Host "*****MFA Activation Tool*****" -ForegroundColor Green
Write-Host "Enter email address or type" -NoNewline
Write-Host " [quit] " -ForegroundColor Yellow -NoNewline
Write-Host "to go back to previous menu: " -NoNewline
$uname = Read-Host
    if ($uname -eq 'quit' -or $uname -eq '')
    {
    return mfa_management
    }
    else
    {

    $result = Get-MsolUser -userprincipalname $uname -ErrorAction 0
        if (!$result)
        {
        Write-Host "Nothing found. Please try again."
        Read-Host -Prompt "Press Enter to continue"

        return verify_activate_mfa
        }
        else
        {

        $mfastate = Get-MsolUser -UserPrincipalName $uname | select @{N='MFA State';E={($_.StrongAuthenticationRequirements.State)}}

           if ($mfastate -like '@{MFA State=}') #with Disabled status
           {
           Write-Host "***ACCOUNT HOLDER INFORMATION***" -ForegroundColor Yellow
           Get-MsolUser -userprincipalname $uname |  Fl DisplayName,UserprincipalName,@{N='MFA State';E={($_.StrongAuthenticationRequirements.State)}}

           Write-Host "MFA CHECK : MFA is not enabled for this account." -ForegroundColor Red
           Write-Host "Do you want to enable MFA for this account?"-ForegroundColor Green
           Write-Host "Enter Y / N : " -ForegroundColor Yellow -NoNewline
             $confirmMFA = Read-Host
                if ($confirmMFA -eq 'Y')
                {
                $st = New-Object -TypeName Microsoft.Online.Administration.StrongAuthenticationRequirement
                $st.RelyingParty = "*"
                $st.State = “Enabled”
                $sta = @($st)
                Set-MsolUser -UserPrincipalName $uname -UsageLocation US -StrongAuthenticationRequirements $sta
                Write-Host "MFA ENABLED!" -ForegroundColor Green
                Read-Host -Prompt "Press Enter to continue"
                }
                else
                {
                return verify_activate_mfa
                }

           }
           else
           {
           Write-Host "***ACCOUNT HOLDER INFORMATION***" -ForegroundColor Yellow
           Get-MsolUser -userprincipalname $uname |  Fl DisplayName,UserprincipalName,@{N='MFA State';E={($_.StrongAuthenticationRequirements.State)}}
           Write-Host "MFA STATUS : ALREADY ENABLED." -ForegroundColor Green
           Read-Host -Prompt "Press Enter to continue"
           }
        #
        }
    }

return verify_activate_mfa
}
#END activate mfa

#reset mfa start
function reset_mfa()
{

cls
Write-Host "*****MFA RESET TOOL*****" -ForegroundColor Green
Write-Host "Enter email address or type" -NoNewline
Write-Host " [quit] " -ForegroundColor Yellow -NoNewline
Write-Host "to go back to previous menu: " -NoNewline
$uname = Read-Host
    if ($uname -eq 'quit' -or $uname -eq '')
    {
    return mfa_management
    }
    else
    {

    $result = Get-MsolUser -userprincipalname $uname -ErrorAction 0
        if (!$result)
        {
        Write-Host "Nothing found. Please try again."
        Read-Host -Prompt "Press Enter to continue"

        return reset_mfa
        }
        else
        {

        $mfastate = Get-MsolUser -UserPrincipalName $uname | select @{N='MFA State';E={($_.StrongAuthenticationRequirements.State)}}

           if ($mfastate -notlike '@{MFA State=}') #with Disabled status
           {
           Write-Host "***ACCOUNT HOLDER INFORMATION***" -ForegroundColor Yellow
           Get-MsolUser -userprincipalname $uname |  Fl DisplayName,UserprincipalName,@{N='MFA State';E={($_.StrongAuthenticationRequirements.State)}}

           Write-Host "Do you really want to RESET MFA for this account?"-ForegroundColor Red
           Write-Host "Enter Y / N : " -ForegroundColor Yellow -NoNewline
             $confirmMFA = Read-Host
                if ($confirmMFA -eq 'Y')
                {
                Reset-MsolStrongAuthenticationMethodByUpn -UserPrincipalName $uname
                Write-Host "MFA has been RESET!" -ForegroundColor Green
                Read-Host -Prompt "Press Enter to continue"
                }
                else
                {
                return reset_mfa
                }
              }
           else
           {
           Write-Host "***ACCOUNT HOLDER INFORMATION***" -ForegroundColor Yellow
           Get-MsolUser -userprincipalname $uname |  Fl DisplayName,UserprincipalName,@{N='MFA State';E={($_.StrongAuthenticationRequirements.State)}}
           Write-Host "MFA STATUS : NOT ENABLED" -ForegroundColor DarkYellow
           Write-host "Reset cannot be done. Please enable MFA for this account." -ForegroundColor Red

           Read-Host -Prompt "Press Enter to continue"
           }

        }
    }

return reset_mfa

}
#reset mfa end

function mfa_management()
{

cls
Write-Host "*****MFA MANAGEMENT TOOL*****" -ForegroundColor Green
Write-Host "1  - Enable MFA " -ForegroundColor Green
Write-Host "2  - Reset MFA " -ForegroundColor Green

Write-Host "Enter the choice number or type " -NoNewline
Write-Host " [quit] " -ForegroundColor Yellow -NoNewline
Write-Host "to go back to previous menu: " -NoNewline

$mfa_choice = Read-Host
    switch  ($mfa_choice)
    {

     'quit' {

        return msol_management

            }
     '1' {

        cls
        verify_activate_mfa

         }

     '2' {
        cls
        reset_mfa
         }

     }

}

function remove_license()
{
Write-Host "*****O365 LICENSE REMOVAL TOOL*****" -ForegroundColor Green

Write-Host "Enter email address or userprincipalname or type" -NoNewline
Write-Host " [quit] " -ForegroundColor Yellow -NoNewline
Write-Host "to go back to previous menu: " -NoNewline
$uname = Read-Host
    if ($uname -eq 'quit' -or $uname -eq '')
    {
    return license_management
    }
    else
    {

    $result = Get-MsolUser -userprincipalname $uname -ErrorAction 0
        if (!$result)
        {
        Write-Host "Nothing found. Please try again."

        return remove_license
        }
        else
        {
        Write-Host "*** USER INFO ***" -ForegroundColor Yellow
        Get-MsolUser -userprincipalname $uname |  Fl UserprincipalName,DisplayName,Licenses
        Write-Host "Enter the license pack to remove from this user or type" -NoNewline
        Write-Host " [quit] " -ForegroundColor Yellow -NoNewline
        Write-Host "to cancel, ex " $global:mytenantnamefinal":ENTERPRISEPACK: " -NoNewline
        $licensepack = Read-Host
            if ($licensepack -eq 'quit' -or $licensepack -eq '')
            {

            return license_management
            }

            Write-Host "Are you sure you want to remove $licensepack from $uname ?" -ForegroundColor Red
            Write-Host "Enter Y / N : " -ForegroundColor Yellow -NoNewline
            $confirmRemove = Read-Host
                if ($confirmRemove -eq 'Y')
                {
                Set-MsolUserLicense -Userprincipalname $uname -RemoveLicenses "$licensepack"
                Get-MsolUser -userprincipalname $uname |  Fl DisplayName,Licenses
                Write-Host "Completed!"
                Read-Host -Prompt "Press Enter to continue"

                }

        }
    }
cls
return remove_license
}

function search_msol_user()
{
cls
Write-Host "*****MSOL USER MANAGEMENT TOOL*****" -ForegroundColor Green
Write-Host "1  - Search by name " -ForegroundColor Green
Write-Host "2  - Search by userprincipalname and view details " -ForegroundColor Green

Write-Host "Enter the choice number or type " -NoNewline
Write-Host " [quit] " -ForegroundColor Yellow -NoNewline
Write-Host "to go back to previous menu: " -NoNewline

$search_msol_group_choice = Read-Host
    switch  ($search_msol_group_choice)
    {

     'quit' {

        return msol_management

            }
     '1' {

        cls
        search_msol_byname

         }

     '2' {
        cls
        search_msol_byuserprincipal
         }

     '3' {
        cls

         }


     }
}

function search_msol_byname()
{
Write-host "*****MSOLUSER SEARCH TOOL*****" -ForegroundColor Green
Write-Host "Enter name or part of it or email address " -NoNewline
Write-Host " [quit] " -ForegroundColor Yellow -NoNewline
Write-Host "to exit search: " -NoNewline
$name = Read-Host
    if ($name -eq 'quit' -or $name -eq '')
    {
    return search_msol_user
    }
    else
    {

    Write-Host "SEARCH RESULT" -ForegroundColor Yellow
    $result = Get-MsolUser -SearchString $name -ErrorAction 0
        if (!$result)
        {
        Write-Host "Nothing found. Please try again."

        return search_msol_byname
        }
        else
        {

        Get-MsolUser -SearchString $name |  Fl DisplayName,UserprincipalName
        search_msol_byname
        }
    }

 }

function search_msol_byuserprincipal()
{
Write-host "*****MSOLUSER SEARCH TOOL*****" -ForegroundColor Green
Write-Host "Enter email address or type " -NoNewline
Write-Host " [quit] " -ForegroundColor Yellow -NoNewline
Write-Host "to exit search: " -NoNewline
$emailadd = Read-Host
    if ($emailadd -eq 'quit' -or $emailadd -eq '')
    {
    return search_msol_user
    }
    else
    {
    Write-Host "SEARCH RESULT" -ForegroundColor Yellow
    $result = Get-MsolUser -userprincipalname $emailadd -ErrorAction 0
        if (!$result)
        {
        Write-Host "Nothing found. Please try again."

        return search_msol_byuserprincipal
        }
        else
        {

        Get-MsolUser -userprincipalname $emailadd |  Fl DisplayName,UserprincipalName,ProxyAddresses,LastPasswordChangeTimestamp,Licenses,@{N='MFA State';E={($_.StrongAuthenticationRequirements.State)}}
        search_msol_byuserprincipal
        }
    }

 }

function msol_sku()
{
Write-Host "*****User Search and License Management Tool*****" -ForegroundColor Green

Write-Host "LICENSES"
Get-MsolAccountSku | Format-Table AccountSkuID,ActiveUnits,ConsumedUnits
Read-Host -Prompt "Press Enter to continue"
cls
msol_management
}

#used for adding/removing mailbox delegation for a user#
function add_fullaccess()
{
Write-Host "*****ADD FULL ACCESS TO MAILBOX*****" -ForegroundColor Green
Write-Host "Enter mailbox name or type" -NoNewline
Write-Host " [quit] " -ForegroundColor Yellow -NoNewline
Write-Host "to go back to previous menu, ex ithelp@$global:mytenantnamefinal.com: " -NoNewline
$mailboxname = Read-Host
    if ($mailboxname -eq 'quit' -or $mailboxname -eq '')
    {
    return exchange_management
    }
    else
    {
        $mresult = Get-Mailbox -identity $mailboxname -ErrorAction 0

        if (!$mresult)
        {
        Write-Host "MAILBOX NOT FOUND. Please verify or try another name. If you just assigned a license please give it 5 mins and try again."

        return add_fullaccess
        }
        else
        {
        Write-Host "Enter email address of the user you want to give the access to or type" -NoNewline
        Write-Host " [quit] " -ForegroundColor Yellow -NoNewline
        Write-Host "to exit: " -NoNewline
        $uname = Read-Host
            if ($uname -eq 'quit' -or $uname -eq '')
            {
            cls
            return add_fullaccess
            }

             $result = Get-MsolUser -userprincipalname $uname -ErrorAction 0
             if (!$result)
              {
                Write-Host "EMAIL ACCOUNT NOT FOUND. Please verify name and start over."

                return add_fullaccess
              }

             else
             {
            Write-Host "**MAILBOX DELEGATION STATUS**" -ForegroundColor Yellow
            Write-Host "for Account: $mailboxname" -ForegroundColor Yellow
            Get-MailboxPermission -identity $mailboxname | Format-Table
            Get-RecipientPermission -identity $mailboxname | Format-Table
            Write-Host "---------- ADD TRUSTEE:----------"
            Write-Host "**USER INFORMATION**" -ForegroundColor Yellow

            Get-MsolUser -UserPrincipalName $uname | select Displayname,UserprincipalName | Format-Table

            Write-Host "ASSIGN $uname FULL ACCESS to $mailboxname mailbox?" -ForegroundColor Green
            Write-Host "Enter Y / N : " -ForegroundColor Yellow -NoNewline
            $confirmAssign = Read-Host
                if ($confirmAssign -eq 'Y')
                {

                Add-MailboxPermission -Identity $mailboxname -User $uname -AccessRights FullAccess -InheritanceType All

                #start
                Write-Host "ASSIGN $uname SEND AS access to $mailboxname mailbox?" -ForegroundColor Green
                Write-Host "Enter Y / N : " -ForegroundColor Yellow -NoNewline
                    $confirmAssignSend = Read-Host
                        if ($confirmAssignSend -eq 'Y')
                        {
                        Add-RecipientPermission -Identity $mailboxname -Trustee $uname -AccessRights SendAs -Confirm:$false
                        }
                #end
                Write-Host "**MAILBOX DELEGATION STATUS**" -ForegroundColor Yellow
                Write-Host "for Account: $mailboxname" -ForegroundColor Yellow
                Get-MailboxPermission -identity $mailboxname | Format-Table
                Write-Host "----------"

                Write-Host "Completed!"

                Read-Host -Prompt "Press Enter to continue"

                }
             }
        }
    }
cls
return add_fullaccess
}

#use this to remove mailbox delegation
function remove_fullaccess()
{
Write-Host "*****REMOVE FULL ACCESS FROM MAILBOX*****" -ForegroundColor Green
Write-Host "Enter mailbox name or type" -NoNewline
Write-Host " [quit] " -ForegroundColor Yellow -NoNewline
Write-Host "to go back to previous menu, ex ithelp@$global:mytenantnamefinal.com: " -NoNewline
$mailboxname = Read-Host
    if ($mailboxname -eq 'quit' -or $mailboxname -eq '')
    {
    return exchange_management
    }
    else
    {
        $mresult = Get-Mailbox -identity $mailboxname -ErrorAction 0

        if (!$mresult)
        {
        Write-Host "MAILBOX NOT FOUND. Please verify or try another name. If you just assigned a license please give it 5 mins and try again."

        return remove_fullaccess
        }
        else
        {
        Write-Host "**MAILBOX DELEGATION STATUS**" -ForegroundColor Yellow
        Write-Host "for Account: $mailboxname" -ForegroundColor Yellow
        Get-MailboxPermission -Identity $mailboxname | Select User,AccessRights | Format-Table
        Write-Host "----------"
        Write-Host "Enter email address you want to REMOVE access from or type" -NoNewline
        Write-Host " [quit] " -ForegroundColor Yellow -NoNewline
        Write-Host "to cancel: " -NoNewline
        $uname = Read-Host
            if ($uname -eq 'quit' -or $uname -eq '')
            {
            cls
            return remove_fullaccess
            }

             $result = Get-MsolUser -userprincipalname $uname -ErrorAction 0
             if (!$result)
              {
                Write-Host "EMAIL ACCOUNT NOT FOUND. Please verify name and start over."

                return remove_fullaccess
              }

             else
             {

            Write-Host "----------REMOVE TRUSTEE:----------"
            Write-Host "**USER INFORMATION**" -ForegroundColor Yellow
            Get-MsolUser -UserPrincipalName $uname | select Displayname,UserprincipalName | Format-Table

            Write-Host "REMOVE $uname ACCESS from $mailboxname mailbox?" -ForegroundColor Green
            Write-Host "Enter Y / N : " -ForegroundColor Yellow -NoNewline
            $confirmAssign = Read-Host
                if ($confirmAssign -eq 'Y')
                {
                Write-Host "**REMOVING FULL PERMISSION..." -ForegroundColor Yellow
                Remove-MailboxPermission -Identity $mailboxname -User $uname -AccessRights FullAccess -InheritanceType All -Confirm:$false
                Write-Host "**REMOVING SEND PERMISSION..." -ForegroundColor Yellow
                Remove-RecipientPermission -Identity $mailboxname -Trustee $uname -AccessRights SendAs -Confirm:$false
                Write-Host "**MAILBOX DELEGATION STATUS**" -ForegroundColor Yellow
                Write-Host "for Account: $mailboxname" -ForegroundColor Yellow
                Get-MailboxPermission -identity $mailboxname | Format-Table
                Get-RecipientPermission -identity $mailboxname | Format-Table
                Write-Host "----------"

                Write-Host "Completed!"

                Read-Host -Prompt "Press Enter to continue"

                }
             }
        }
    }
cls

return remove_fullaccess
}

#use this to view mailbox delegation
function view_mailboxpermission()
{
Write-Host "*****VIEW MAILBOX PERMISSIONS*****" -ForegroundColor Green
Write-Host "Enter mailbox name or type" -NoNewline
Write-Host " [quit] " -ForegroundColor Yellow -NoNewline
Write-Host "to go back to previous menu, ex ithelp@$global:mytenantnamefinal.com: " -NoNewline
$mailboxname = Read-Host
    if ($mailboxname -eq 'quit' -or $mailboxname -eq '')
    {
    return exchange_management
    }
    else
    {
        $mresult = Get-Mailbox -identity $mailboxname -ErrorAction 0

        if (!$mresult)
        {
        Write-Host "MAILBOX NOT FOUND. Please verify or try another name. If you just assigned a license please give it 5 mins and try again."

        return view_mailboxpermission
        }
        else
        {
            Write-Host "**MAILBOX DELEGATION STATUS**" -ForegroundColor Yellow
            Write-Host "$mailboxname" -ForegroundColor Yellow
            Write-host "----------FULL ACCESS----------" -ForegroundColor Yellow
            Get-MailboxPermission -identity $mailboxname | Select User | Format-Table
            Write-host "----------SEND AS ACCESS----------" -ForegroundColor Yellow
            Get-RecipientPermission -Identity $mailboxname | Select Trustee | Format-Table
            Write-Host "----------"
            Read-Host -Prompt "Press Enter to continue"
        }
    }
cls

return view_mailboxpermission
}

#updated to use name connect_exchange_online as connect_exchange function is already present in profile.ps1
function connect_exchange_online() {

    Import-Module exchangeonlinemanagement
    Write-Host "Connecting to Exchange Online..."
    Connect-ExchangeOnline -UserPrincipalName $myemailaddress -ShowProgress:$true
}

function check_connections_status()
{
$global:statuseop = $null;
$global:statusmsol = $null;
$global:statusspo = $null;

Write-Host "CONNECTION STATUS " -ForegroundColor Yellow

#EOP
$checktoverifyeop = Get-Mailbox -ResultSize 1 -WarningAction 0

if (!$checktoverifyeop)
    {
    $global:statuseop = "(connected)"
    Write-Host "Exchange : $global:statuseop"
    }
    else
    {
    $global:statuseop = "(connected)"
    Write-Host "Exchange : $global:statuseop"
    }

#MSOL
$checktoverifymsol = (Get-MsolDomain | Where-Object {$_.isInitial}).name
if (!$checktoverifymsol)
    {
    $global:statusmsol = "(not connected)"
    Write-Host "MSOL : $global:statusmsol"
    }
    else
    {
    $global:statusmsol = "(connected)"
    Write-Host "MSOL : $global:statusmsol"
    }

#SPO
$checktoverifyspo = Get-SPOSite -Limit 1 -WarningAction 0
if (!$checktoverifyspo)
    {
    $global:statusspo = "(not connected)"
    Write-Host "SPO : $global:statusspo"
    }
    else
    {
    $global:statusspo = "(connected)"
    Write-Host "SPO : $global:statusspo"
    }

Write-Host "Please run myo365tools again to start using the tools."

}

#start spo scripts
function add_temp_admin_access($spoaccount)
{
$temp_admin = $myemailaddress
If ($spoaccount -ne $temp_admin){
Set-SPOUser -Site https://$global:mytenantnamefinal-my.sharepoint.com/personal/$spoaccount -LoginName $temp_admin -IsSiteCollectionAdmin $True | Out-Null
}
#if statement is used to not add self as admin to own account
}

function remove_temp_admin_access($spoaccount)
{
$temp_admin = $myemailaddress
If ($spoaccount -ne $temp_admin){
Set-SPOUser -Site https://$global:mytenantnamefinal-my.sharepoint.com/personal/$spoaccount -LoginName $temp_admin -IsSiteCollectionAdmin $False | Out-Null
}
 #if statement is to make sure you do not remove yourself as owner of your own OneDrive account
}


function connect_spo()
{

Write-Host "Connecting to Sharepoint Online..."
Connect-SPOService -Url https://$global:mytenantnamefinal-admin.sharepoint.com #-Credential $cred

}

function disconnect_spo()
{
Disconnect-SPOService

}


function view_spo_account()
{
Write-host "*****SHAREPOINT/ONEDRIVE ACCOUNT VIEWER*****" -ForegroundColor Green
Write-Host "Enter email address of the onedrive account holder or type" -NoNewline
Write-Host " [quit] " -ForegroundColor Yellow -NoNewline
Write-Host "to go back to previous menu, ex user@$global:mytenantnamefinal.com: " -NoNewline


$spoemailaddress = Read-Host

  if ($spoemailaddress -eq 'quit' -or $spoemailaddress -eq '')
  {
  cls
  return onedrive_management_tool
  }


$spoprofilename = $spoemailaddress.Replace(".","_").Replace("@","_")

$checktoverify = Get-SPOSite -Identity "https://$global:mytenantnamefinal-my.sharepoint.com/personal/$spoprofilename" | Select-Object -ExpandProperty Status
if ($checktoverify -eq "Active")
    {

    #give me temp admin access
    add_temp_admin_access $spoprofilename
    Write-Host "Giving self temp admin access to view ownership info..."
    #Read-Host -Prompt "Press Enter to continue"
    Start-Sleep 2
    cls
    Write-host "*****SHAREPOINT/ONEDRIVE ACCOUNT VIEWER*****" -ForegroundColor Green
    Write-Host "----------ONEDRIVE ACCOUNT HOLDER INFORMATION---------- " -ForegroundColor Yellow
    write-host "ACCOUNT NAME : $spoemailaddress" -ForegroundColor Yellow
    Get-SPOSite -Identity "https://$global:mytenantnamefinal-my.sharepoint.com/personal/$spoprofilename"  | Select Title,Status,SharingCapability,Url | Format-List
    Write-Host "----------USERS WITH ACCESS TO THIS ONEDRIVE ACCOUNT----------" -ForegroundColor Yellow
    Write-Host "TRUSTEES:" -ForegroundColor Yellow
    Write-host "Note: Your account was added and listed here as temp trustee in order to view this information. Temp access was removed" -ForegroundColor DarkYellow
    Get-SPOUser -Site "https://$global:mytenantnamefinal-my.sharepoint.com/personal/$spoprofilename" -Limit All | Select LoginName, IsSiteAdmin | ? { $_.ISSiteAdmin } | Format-Table
    #removes my temp admin access

    remove_temp_admin_access $spoprofilename

    view_spo_account
    }
    else
    {
    Write-Host "ACCOUNT NOT FOUND. Please try again"

    return view_spo_account
    }
}

##grant user access to another person's onedrive
#start
function add_access_to_spo()
{
Write-Host "*****ADD FULL ACCESS TO ONEDRIVE ACCOUNT*****" -ForegroundColor Green
Write-Host "Enter email address of the onedrive account holder or type" -NoNewline
Write-Host " [quit] " -ForegroundColor Yellow -NoNewline
Write-Host "to go back to previous menu, ex user@$global:mytenantnamefinal.com: " -NoNewline
$spoemailaddress = Read-Host
    if ($spoemailaddress -eq 'quit' -or $spoemailaddress -eq '')
    {
    cls
    return onedrive_management_tool
    }
    else
    {
        $spoprofilename = $spoemailaddress.Replace(".","_").Replace("@","_")
        $mresult = Get-SPOSite -Identity "https://$global:mytenantnamefinal-my.sharepoint.com/personal/$spoprofilename"

        if (!$mresult)
        {
        Write-Host "ACCOUNT NOT FOUND. Please check the email address and try again."

        return add_access_to_spo
        }
        else
        {
        Write-Host "Enter email address of the user you want to give the access to or type" -NoNewline
        Write-Host " [quit] " -ForegroundColor Yellow -NoNewline
        Write-Host "to exit: " -NoNewline
        $trustee = Read-Host
            if ($trustee -eq 'quit' -or $trustee -eq '')
            {
            cls
            return add_access_to_spo
            }

             $result = Get-MsolUser -userprincipalname $trustee | Select DisplayName
             if (!$result)
              {
                Write-Host "EMAIL ACCOUNT NOT FOUND. Please check email address and try again."

                return add_access_to_spo
              }

             else
             {
            cls
            Write-Host "*****ADD FULL ACCESS TO ONEDRIVE ACCOUNT*****" -ForegroundColor Green
            Write-Host "----------ONEDRIVE ACCOUNT HOLDER INFORMATION---------- " -ForegroundColor Yellow
            write-host "ACCOUNT NAME : $spoemailaddress" -ForegroundColor Yellow
            Get-SPOSite -Identity "https://$global:mytenantnamefinal-my.sharepoint.com/personal/$spoprofilename"  | Format-List Title,Status,SharingCapability,Url

            Write-Host "----------TRUSTEE----------"
            Write-Host "**USER INFORMATION**" -ForegroundColor Yellow
            Get-MsolUser -UserPrincipalName $trustee | select Displayname,UserprincipalName | Format-Table

            Write-Host "ASSIGN $trustee FULL ACCESS to $spoemailaddress OneDrive?" -ForegroundColor Green
            Write-Host "Enter Y / N : " -ForegroundColor Yellow -NoNewline
            $confirmAssign = Read-Host
                if ($confirmAssign -eq 'Y')
                {
                add_temp_admin_access $spoprofilename

                Set-SPOUser -Site https://$global:mytenantnamefinal-my.sharepoint.com/personal/$spoprofilename -LoginName $trustee -IsSiteCollectionAdmin $True | Out-Null
                cls
                Write-Host "*****ADD FULL ACCESS TO ONEDRIVE ACCOUNT*****" -ForegroundColor Green
                Write-Host "----------ONEDRIVE ACCOUNT HOLDER INFORMATION---------- " -ForegroundColor Yellow
                write-host "ACCOUNT NAME : $spoemailaddress" -ForegroundColor Yellow
                Get-SPOSite -Identity "https://$global:mytenantnamefinal-my.sharepoint.com/personal/$spoprofilename"  | Format-List Title,Status,SharingCapability,Url


                Write-Host "----------USERS WITH ACCESS TO THIS ONEDRIVE ACCOUNT----------" -ForegroundColor Yellow
                Write-Host "TRUSTEES:" -ForegroundColor Yellow
                Write-host "Note: Your account was added and listed here as temp trustee in order to view this information. Temp access will be removed on exit" -ForegroundColor DarkYellow
                Get-SPOUser -Site "https://$global:mytenantnamefinal-my.sharepoint.com/personal/$spoprofilename" -Limit All | Select LoginName, IsSiteAdmin | ? { $_.ISSiteAdmin } | Format-Table

                Write-Host "Completed!"
                Write-Host "Note: You can copy the URL above and provide it to the TRUSTEE." -ForegroundColor Yellow
                Write-Host "----------"
                remove_temp_admin_access $spoprofilename

                Read-Host -Prompt "Press Enter to continue"

                }

             }
        }
    }
cls
return add_access_to_spo

}
##end

#removes spo access for a user
function remove_access_to_spo()
{
Write-Host "*****REMOVE USER ACCESS FROM ONEDRIVE ACCOUNT*****" -ForegroundColor Green
Write-Host "Enter email address of the onedrive account holder or type" -NoNewline
Write-Host " [quit] " -ForegroundColor Yellow -NoNewline
Write-Host "to go back to previous menu, ex user@$global:mytenantnamefinal.com: " -NoNewline
$spoemailaddress = Read-Host
    if ($spoemailaddress -eq 'quit' -or $spoemailaddress -eq '')
    {
    cls
    return onedrive_management_tool
    }
    else
    {
        $spoprofilename = $spoemailaddress.Replace(".","_").Replace("@","_")
        $mresult = Get-SPOSite -Identity "https://$global:mytenantnamefinal-my.sharepoint.com/personal/$spoprofilename"

        if (!$mresult)
        {
        Write-Host "ACCOUNT NOT FOUND. Please check the email address and try again."

        return remove_access_to_spo
        }
        else
        {
        add_temp_admin_access $spoprofilename
        cls
        Write-Host "*****REMOVE USER ACCESS FROM ONEDRIVE ACCOUNT*****" -ForegroundColor Green
        Write-Host "----------ONEDRIVE ACCOUNT HOLDER INFORMATION---------- " -ForegroundColor Yellow
        Write-host "ACCOUNT NAME : $spoemailaddress" -ForegroundColor Yellow

        Get-SPOSite -Identity "https://$global:mytenantnamefinal-my.sharepoint.com/personal/$spoprofilename"  | Select Title,Status,SharingCapability,Url | Format-List
        Write-Host "----------USERS WITH ACCESS TO THIS ONEDRIVE ACCOUNT----------" -ForegroundColor Yellow
        Write-Host "TRUSTEES:" -ForegroundColor Yellow
        Write-host "Note: Your account was added and listed here as temp trustee in order to view this information. Temp access will be removed on exit" -ForegroundColor DarkYellow
        Get-SPOUser -Site "https://$global:mytenantnamefinal-my.sharepoint.com/personal/$spoprofilename" -Limit All | Select LoginName, IsSiteAdmin | ? { $_.ISSiteAdmin } | Format-Table

        Write-Host "Enter the email address that you want the access removed from or type" -NoNewline
        Write-Host " [quit] " -ForegroundColor Yellow -NoNewline
        Write-Host "to exit: " -NoNewline
        $trustee = Read-Host
            if ($trustee -eq 'quit' -or $trustee -eq '')
            {
            cls
            remove_temp_admin_access $spoprofilename
            return remove_access_to_spo
            }

             $result = Get-MsolUser -userprincipalname $trustee | Select DisplayName
             if (!$result)
              {
                Write-Host "EMAIL ACCOUNT NOT FOUND. Please check email address and try again."
                remove_temp_admin_access $spoprofilename
                return remove_access_to_spo
              }

             else
             {
            cls
            Write-Host "*****REMOVE USER ACCESS FROM ONEDRIVE ACCOUNT*****" -ForegroundColor Green
            Write-Host "----------ONEDRIVE ACCOUNT HOLDER INFORMATION---------- " -ForegroundColor Yellow
            write-host "ACCOUNT NAME : $spoemailaddress" -ForegroundColor Yellow

            Get-SPOSite -Identity "https://$global:mytenantnamefinal-my.sharepoint.com/personal/$spoprofilename"  | Format-List Title,Status,SharingCapability,Url

            Write-Host "----------TRUSTEE----------"
            Write-Host "**USER INFORMATION**" -ForegroundColor Yellow
            Get-MsolUser -UserPrincipalName $trustee | select Displayname,UserprincipalName | Format-Table

            Write-Host "REMOVE $trustee FULL ACCESS from $spoemailaddress OneDrive?" -ForegroundColor Red
            Write-Host "Enter Y / N : " -ForegroundColor Yellow -NoNewline
            $confirmAssign = Read-Host
                if ($confirmAssign -eq 'Y')
                {
                Set-SPOUser -Site https://$global:mytenantnamefinal-my.sharepoint.com/personal/$spoprofilename -LoginName $trustee -IsSiteCollectionAdmin $False | Out-Null
                cls
                Write-Host "*****REMOVE USER ACCESS FROM ONEDRIVE ACCOUNT*****" -ForegroundColor Green
                Write-Host "----------ONEDRIVE ACCOUNT HOLDER INFORMATION---------- " -ForegroundColor Yellow
                Write-host "for email account $spoemailaddress" -ForegroundColor Yellow
                Get-SPOSite -Identity "https://$global:mytenantnamefinal-my.sharepoint.com/personal/$spoprofilename"  | Format-List Title,Status,SharingCapability,Url


                Write-Host "----------USERS WITH ACCESS TO THIS ONEDRIVE ACCOUNT----------" -ForegroundColor Yellow
                Write-Host "TRUSTEES:" -ForegroundColor Yellow
                Write-host "Note: Your account was added and listed here as temp trustee in order to view this information. Temp access will be removed on exit" -ForegroundColor DarkYellow
                Get-SPOUser -Site "https://$global:mytenantnamefinal-my.sharepoint.com/personal/$spoprofilename" -Limit All | Select LoginName, IsSiteAdmin | ? { $_.ISSiteAdmin } | Format-Table

                Write-Host "Completed!" -ForegroundColor DarkYellow
                Write-Host "----------"
                remove_temp_admin_access $spoprofilename

                Read-Host -Prompt "Press Enter to continue"
                }
                else
                {
                remove_temp_admin_access $spoprofilename
                }
             }
        }
    }
cls

return remove_access_to_spo
}
#end remove spo access for a user

#start give self access
function add_self_access_to_spo()
{
Write-Host "*****ASSIGN SELF TEMPORARY FULL ACCESS TO ONEDRIVE ACCOUNT*****" -ForegroundColor Green
Write-Host "Enter email address of the onedrive account holder or type" -NoNewline
Write-Host " [quit] " -ForegroundColor Yellow -NoNewline
Write-Host "to go back to previous menu, ex user@$global:mytenantnamefinal.com: " -NoNewline
$spoemailaddress = Read-Host
    if ($spoemailaddress -eq 'quit' -or $spoemailaddress -eq '')
    {
    cls
    return onedrive_management_tool
    }
    else
    {
        $spoprofilename = $spoemailaddress.Replace(".","_").Replace("@","_")
        $mresult = Get-SPOSite -Identity "https://$global:mytenantnamefinal-my.sharepoint.com/personal/$spoprofilename"

        if (!$mresult)
        {
        Write-Host "ACCOUNT NOT FOUND. Please check the email address and try again."

        return add_self_access_to_spo
        }
        else
        {

            Write-Host "ASSIGN YOURSELF FULL ACCESS to $spoemailaddress OneDrive?" -ForegroundColor Green
            Write-Host "Enter Y / N : " -ForegroundColor Yellow -NoNewline
            $confirmAssign = Read-Host
                if ($confirmAssign -eq 'Y')
                {
                add_temp_admin_access $spoprofilename

                cls
                Write-Host "*****ADD SELF TEMPORARY FULL ACCESS TO ONEDRIVE ACCOUNT*****" -ForegroundColor Green
                Write-Host "----------ONEDRIVE ACCOUNT HOLDER INFORMATION---------- " -ForegroundColor Yellow
                write-host "ACCOUNT NAME : $spoemailaddress" -ForegroundColor Yellow
                Get-SPOSite -Identity "https://$global:mytenantnamefinal-my.sharepoint.com/personal/$spoprofilename"  | Format-List Title,Status,SharingCapability,Url


                Write-Host "----------USERS WITH ACCESS TO THIS ONEDRIVE ACCOUNT----------" -ForegroundColor Yellow
                Write-Host "TRUSTEES:" -ForegroundColor Yellow
                Write-host "Note: Your account was added as temp trustee. Temp access will be removed on exit" -ForegroundColor DarkYellow
                Get-SPOUser -Site "https://$global:mytenantnamefinal-my.sharepoint.com/personal/$spoprofilename" -Limit All | Select LoginName, IsSiteAdmin | ? { $_.ISSiteAdmin } | Format-Table

                Write-Host "Completed!"
                Write-Host "You can access the files using the URL above" -ForegroundColor DarkYellow
                Write-Host "----------"

                Read-Host -Prompt "Press Enter when you are ready to close and remove your temp access."
                remove_temp_admin_access $spoprofilename

                }

        }
    }
cls
return add_self_access_to_spo
}
#end give self access to user onedrive

#spo menu start
function onedrive_management_tool()
{
cls

Write-Host "*****ONEDRIVE ACCESS MANAGEMENT TOOL*****" -ForegroundColor Green
Write-Host "1  - View User OneDrive information" -ForegroundColor Green
Write-Host "2  - Add Access to user OneDrive" -ForegroundColor Green
Write-Host "3  - Grant self access to user OneDrive" -ForegroundColor Green
Write-Host "4  - Remove Access from user OneDrive" -ForegroundColor Green
Write-Host "Enter the choice number or or type " -NoNewline
Write-Host " [quit] " -ForegroundColor Yellow -NoNewline
Write-Host "to exit: " -NoNewline

$spo_group_choice = Read-Host
    switch  ($spo_group_choice)
    {

     'quit' {

        return myo365tools

            }
     '1' {

        cls
        view_spo_account


         }
     '2' {
        cls
        add_access_to_spo

          }
     '3' {
        cls
        add_self_access_to_spo
         }

     '4' {
        cls
        remove_access_to_spo
         }

     }
}
#spo menu end
#end spo scripts
###END MYO365TOOLS###

# SIG # Begin signature block
# MIITjwYJKoZIhvcNAQcCoIITgDCCE3wCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUH3OtZIs8NcO+iVM3IGAmEqK8
# sXqgghDGMIIFRDCCBCygAwIBAgIRAPObRmxze0JQ5eGP2ElORJ8wDQYJKoZIhvcN
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
# hkiG9w0BCQQxFgQU7crsYkV+rP+boxxTJq/P8x5Qxb0wDQYJKoZIhvcNAQEBBQAE
# ggEAnM48nmBODL1DDKETWX8IBV1d3CxWamVEOevCbw9OJ+uW3rxIyyglV8bW1zcQ
# Y+P7UaeeN0e+unkdLN575umPKFc5i6TxTv9Qy36ViTSPWz4nmrCR4Sz37MySwZEC
# y8DxOBZCHM55pHTCH/vhCnPdoVHdiExbBj6h214D5p3xYJRmwgCEstyC8wnNejNR
# PNNchQHprOb5TV0sgDbsfXknnmbZsAdOD8MN1hUDjwvwvsHD4sNkg4Y0rZI4Te+z
# 97k4OYhW4nHfb/+Od1M2Q29b2wR0pltI5I2IQNo4aW0kkz18BE7es+/R+Sm/6crc
# Ko57k5Jg6ypJH4thCPTaULwyuQ==
# SIG # End signature block
