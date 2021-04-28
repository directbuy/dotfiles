Set-ExecutionPolicy Bypass

function gotoPowerShellDirectory {
    $target = $profile.Substring(0,$profile.LastIndexOf('\'))
    Set-Location $target
}
function u_dir() {Set-Location 'c:/u'}
function go_fling($start=$false)
{ 
    set-Location "C:/u/fleeting_fling"
    if ($start) { start_fling }
}

function djact_fling() {
    if ((Test-Path ".wenv") -and (Test-Path ".wenv\scripts\activate.ps1")) {
        . .wenv\scripts\activate.ps1
    }
    else {
        $name = ([io.fileinfo]"$pwd").basename
        workon $name
    }
    $env:TUNDRA_ENV="local_docker"
}


function start_fling() {	
	Set-Location -Path 'c:/u/fleeting_fling'
	docker-compose start
	djact_fling
	djsp
}

Set-Alias fling go_fling
Set-Alias psdir gotoPowerShellDirectory
Set-Alias cu u_dir

<#  function for fun and example of how to isue webrequest in POSH #>
function weather($city="Chicago") {
    $weather = (Invoke-WebRequest "https://wttr.in/${city}" -UserAgent "curl").content
    $weather = $weather -split "`n"
    for ($x = 0; $x -lt 17; ++$x) {
        Write-Host $weather[$x]
    }
}

<# function as example of some basic POSH script syntax #>
function goodMorning {
    [OutputType([string])]
    Param
    (
        # Say hello to
        [Parameter(Mandatory=$false, ValueFromPipelineByPropertyName=$true, Position=0)]
        [string]$To
    )
    Begin
    {
        if(-not $To)
        {  
            Write-Verbose 'Retrieving current username'         
            $To = $env:Username
        }
    }
    Process
    {
        Write-Host "Hello $To" -ForegroundColor Green
    }
    End {}    
}