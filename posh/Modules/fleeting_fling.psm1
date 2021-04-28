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
