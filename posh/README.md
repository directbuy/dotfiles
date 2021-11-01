Setup
=====

Welcome to dotfiles for posh, too!

In order to setup:

```posh
choco install python3 --version=3.8.10 -y --params '/quiet TargetDir=c:\python38'
cd /path/to/dotfiles
cd posh
powershell.exe -executionpolicy bypass .\setup.ps1
cp profile.ps1 $profile
```

special notes for fleeting fling
================================

If you use the fleeting_fling.psm1 POSH module you can see that the start_fling function will set the TUNDRA_ENV environment variable.

However, if you regularly start shell_plus or otherwise need that variable set and don't want to run that function everytime, you can set the environment variable to persist as a user setting with the POSH command:

`[System.Environment]::SetEnvironmentVariable('TUNDRA_ENV', 'local_docker', [System.EnvironmentVariableTarget]::User)`
