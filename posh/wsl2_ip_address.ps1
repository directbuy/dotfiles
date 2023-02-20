<#
    .SYNOPSIS
        sets the wsl2 address of the focal wsl2 instance to 192.168.201.248/29
        using that cidr range prevents conflicts with the various vpns we
        have as well as ensures that we play nice with our aws and on-prem
        environments

    .PARAMETER install
        if this switch is specified, we will install this script to run
        as a job at startup
#>
[CmdletBinding()]
param(
  [Parameter()][switch]$install
)
$my_path = $myInvocation.myCommand.path
$dir = split-path $my_path -parent
$hcn_path = join-path $dir "hcn"

if ($install) {
    $job_name = "set_wsl2_ip_address"
    $job = Get-ScheduledJob -Name $job_name -ErrorAction SilentlyContinue
    if ($job) {
        Write-Host "job has already been installed"
    }
    else {
        Write-Host "installing"
        $trigger = New-JobTrigger -AtStartup -RandomDelay 00:00:30
        Register-ScheduledJob -Trigger $trigger `
            -FilePath $my_path `
            -Name $job_name
    }
    return
}
Stop-Process -Name pycharm64 -ErrorAction silentlycontinue
wsl -d focal --shutdown
import-module -Name $hcn_path

$network = @"
{
    "Name" : "WSL",
    "Flags": 9,
    "Type": "ICS",
    "IPv6": false,
    "IsolateSwitch": true,
    "MaxConcurrentEndpoints": 1,
    "Subnets" : [{
        "ID" : "FC437E99-2063-4433-A1FA-F4D17BD55C92",
        "ObjectType": 5,
        "AddressPrefix" : "192.168.201.248/29",
        "GatewayAddress" : "192.168.201.249",
        "IpSubnets" : [
            {
                "ID" : "4D120505-4143-4CB2-8C53-DC0F70049696",
                "Flags": 3,
                "IpAddressPrefix": "192.168.201.248/29",
                "ObjectType": 6
            }
        ]
    }],
    "MacPools":  [{
        "EndMacAddress":  "00-15-5D-52-CF-FF",
        "StartMacAddress":  "00-15-5D-52-C0-00"
    }],
    "DNSServerList" : "192.168.201.251, 192.168.201.252"
}
"@

$rg = Get-HnsNetworkEx | Where-Object { $_.Name -Eq "WSL" } | Remove-HnsNetwork
$id = "B95D0C5E-57D4-412B-B571-18A81A16E005"
New-HnsNetworkEx -Id $id -JsonString $network
