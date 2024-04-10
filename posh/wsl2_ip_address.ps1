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
  , [Parameter()][switch]$force
)
$my_path = $PSScriptRoot
$dir = split-path $my_path -parent
$log_file = [io.path]::GetFileNameWithoutExtension($my_path)
$log_dir = "$($env:home)\logs"
if (!(Test-Path $log_dir)) {
    mkdir $log_dir
}
$log_file = join-path $log_dir $log_file
function log($message) {
    Write-Host $message
    Add-Content -Path $log_file $message
}
log "dir: [$($dir)]"
$hcn_path = join-path $dir "posh\hcn"
$windows_version = (Get-WmiObject -class Win32_OperatingSystem).Caption
if ($install) {
    $job_name = "set_wsl2_ip_address"
    $job = Get-ScheduledJob -Name $job_name -ErrorAction SilentlyContinue
    if ($job) {
        Write-Host "job has already been installed"
        if ($force) {
            Write-Host "removing scheduled job"
            Unregister-ScheduledJob -Name $job_name
        }
    }
    else {
        Write-Host "installing"
        $trigger = New-JobTrigger -AtStartup
        Register-ScheduledJob -Trigger $trigger `
            -FilePath $my_path `
            -Name $job_name
    }
    return
}
function remove_health($data) {
    if ($data.health) {
        $data.psobject.properties.remove('health')
    }
    foreach ($subnet in $data.subnets) {
        if ($subnet.health) {
            $subnet.psobject.properties.remove('health')
        }
        foreach ($ip_subnet in $subnet.ipsubnets) {
            if ($ip_subnet.health) {
                $ip_subnet.psobject.properties.remove('health')
            }

        }
    }
    if ($data.resources.health) {
        $data.resources.psobject.properties.remove('health')
    }
    foreach ($allocator in $data.resources.allocators) {
        if ($allocator.health) {
            $allocator.psobject.properties.remove('health')
        }
    }
    return $data
}

function set_network_cidr($name, $desired_cidr, $gateway_ip) {
    import-module -Name $hcn_path
    import-module microsoft.powershell.utility
    $wsl_network = Get-HnsNetworkEx | Where-Object { $_.Name -like "$($name)*" }
    $first_ip = $desired_cidr.split("/")[0]
    $network = $null
    log "setting first ip to [$($first_ip)]"
    if ($wsl_network) {
        $name = $wsl_network.name
        $id = $wsl_network.id
        log "existing network found $($name) / $($id)"
        $subnet = $wsl_network.subnets[0]
        if ($subnet.addressprefix -eq $desired_cidr) {
            log "network [$($name)] cidr is alread [$($desired_cidr)]"
            return
        }
        if ($name -like 'WSL*') {
            log "shutting down focal"
            wsl -d focal --shutdown
        }
        log "removing existing network [$($name)]"
        $wsl_network | Remove-HnsNetwork
        $wsl_network = remove_health $wsl_network
        if ($wsl_network.DNSServerList){
            $wsl_network.DNSServerList = $gateway_ip
        }
        $subnet.addressprefix = $desired_cidr
        $subnet.GatewayAddress = $gateway_ip
        $subnet.ipsubnets[0].IpAddressPrefix = $desired_cidr
        foreach ($allocator in $wsl_network.resources.allocators) {
            if ($allocator.SubnetIPAddress) {
                $allocator.SubnetIPAddress = $first_ip
            }
        }
        $network = ConvertTo-Json -Depth 7 $wsl_network
    }
    else {
        if ($name -like 'WSL*') {
            $name = "WSL (Hyper-V firewall)"
            $id = "790E58B4-7939-4434-9358-89AE7DDBE87E"
            $network = @"
{
  "ActivityId":  "E2636C76-ACBD-4FBC-BACA-AA98B303B0F6",
  "AdditionalParams":  {},
  "CurrentEndpointCount":  1,
  "DNSServerList":  "$($gateway_ip)",
  "Extensions":  [{
    "Id":  "E7C3B2F0-F3C5-48DF-AF2B-10FED6D72E7A",
    "IsEnabled":  false,
    "Name":  "Microsoft Windows Filtering Platform"
  }, {
    "Id":  "F74F241B-440F-4433-BB28-00F89EAD20D8",
    "IsEnabled":  true,
    "Name":  "Microsoft Azure VFP Switch Filter Extension"
  }, {
    "Id":  "430BDADD-BAB0-41AB-A369-94B67FA5BE0A",
    "IsEnabled":  true,
    "Name":  "Microsoft NDIS Capture"
  }],
  "Flags":  265,
  "GatewayMac":  "00-15-5D-BF-C6-40",
  "ID":  "$($id)",
  "IPv6":  false,
  "IsolateSwitch":  true,
  "LayeredOn":  "BFEE2CBD-B935-461C-97FE-2DDDC2AD01A3",
  "MacPools":  [{
    "EndMacAddress":  "00-15-5D-BF-CF-FF",
    "StartMacAddress":  "00-15-5D-BF-C0-00"
  }],
  "MaxConcurrentEndpoints":  1,
  "Name":  "$($name)",
  "NatName":  "ICS21D70693-A6F4-4D9A-A4FE-E0AD81B157FA",
  "Policies":  [],
  "State":  1,
  "Subnets":  [{
    "AdditionalParams":  {},
    "AddressPrefix":  "$($desired_cidr)",
    "Flags":  0,
    "GatewayAddress":  "$($gateway_ip)",
    "ID":  "6411C858-A454-41AC-A92A-3E97BD989397",
    "IpSubnets":  [{
      "AdditionalParams":  {},
      "Flags":  0,
      "ID":  "186DD165-E79E-447F-89B0-DD828D14A741",
      "IpAddressPrefix":  "$($desired_cidr)",
      "ObjectType":  6,
      "Policies":  []
    }],
    "ObjectType":  5,
    "Policies":  []
  }],
  "SwitchGuid":  "$($id)",
  "TotalEndpoints":  1,
  "Type":  "ICS",
  "Version":  64424509440,
  "Resources":  {
    "AdditionalParams":  {},
    "AllocationOrder":  2,
    "Allocators":  [{
      "AdapterNetCfgInstanceId":  "{21D70693-A6F4-4D9A-A4FE-E0AD81B157FA}",
      "AdditionalParams":  {},
      "AllocationOrder":  0,
      "CompartmendId":  0,
      "Connected":  true,
      "DNSFirewallRules":  true,
      "DeviceInstanceID":  "",
      "DevicelessNic":  true,
      "DhcpDisabled":  true,
      "EndpointNicGuid":  "$($id)",
      "EndpointPortGuid":  "$($id)",
      "Flags":  0,
      "ID":  "722637B6-3E8E-46F2-9E86-9EBFDF32B113",
      "InterfaceGuid":  "21D70693-A6F4-4D9A-A4FE-E0AD81B157FA",
      "IsPolicy":  false,
      "IsolationId":  0,
      "MacAddress":  "00-15-5D-B1-69-7B",
      "ManagementPort":  true,
      "NcfHidden":  false,
      "NetworkId":  "$($id)",
      "NicFriendlyName":  "$($name)",
      "NlmHidden":  true,
      "PortFriendlyNamePrefix":  "Host Vnic",
      "PreferredPortFriendlyName":  "Host Vnic $($id)",
      "State":  3,
      "SwitchId":  "$($id)",
      "Tag":  "Host Vnic",
      "VmPort":  false,
      "WaitForIpv6Interface":  false,
      "nonPersistentPort":  false
    }, {
      "AdditionalParams":  {},
      "AllocationOrder":  1,
      "Dhcp":  false,
      "DisableSharing":  false,
      "Dns":  true,
      "ExternalInterfaceConstraint":  0,
      "Flags":  0,
      "ICSDHCPFlags":  0,
      "ICSFlags":  0,
      "ID":  "64F71467-A8BB-4135-B71A-46A01B06F4D4",
      "IsPolicy":  false,
      "Prefix":  20,
      "PrivateInterfaceGUID":  "21D70693-A6F4-4D9A-A4FE-E0AD81B157FA",
      "SubnetIPAddress":  "$($first_ip)",
      "Tag":  "ICS"
    }],
    "CompartmentOperationTime":  0,
    "Flags":  0,
    "ID":  "E2636C76-ACBD-4FBC-BACA-AA98B303B0F6",
    "PortOperationTime":  0,
    "VfpOperationTime":  0,
    "parentId":  "7725BD87-60F2-49DF-A6CD-718D2B1E686E"
  }
}
"@
        }
        elif ($name -like 'default switch') {
            $id = "C08CB7B8-9B3C-408E-8E30-5E16A3AEB444"
            $network = @"
{
  "ActivityId": "4433905F-F5E1-4453-9B24-EC9C1C00B655",
  "AdditionalParams": {},
  "CurrentEndpointCount": 0,
  "Extensions": [
    {
      "Id": "E7C3B2F0-F3C5-48DF-AF2B-10FED6D72E7A",
      "IsEnabled": false,
      "Name": "Microsoft Windows Filtering Platform"
    },
    {
      "Id": "F74F241B-440F-4433-BB28-00F89EAD20D8",
      "IsEnabled": false,
      "Name": "Microsoft Azure VFP Switch Filter Extension"
    },
    {
      "Id": "430BDADD-BAB0-41AB-A369-94B67FA5BE0A",
      "IsEnabled": true,
      "Name": "Microsoft NDIS Capture"
    }
  ],
  "Flags": 11,
  "GatewayMac": "00-15-5D-01-0F-00",
  "ID": "$($id)",
  "IPv6": false,
  "LayeredOn": "D353C64C-4643-4318-8000-D36E21FDDE64",
  "MacPools": [
    {
      "EndMacAddress": "00-15-5D-B5-3F-FF",
      "StartMacAddress": "00-15-5D-B5-30-00"
    }
  ],
  "MaxConcurrentEndpoints": 0,
  "Name": "Default Switch",
  "NatName": "ICSE54B75E2-8E56-443E-BA86-D3384E95F104",
  "Policies": [],
  "State": 1,
  "Subnets": [
    {
      "AdditionalParams": {},
      "AddressPrefix": "$($desired_cidr)",
      "Flags": 0,
      "GatewayAddress": "$($gateway_ip)",
      "ID": "4269C06B-4075-49D0-91BE-680D498A0C7C",
      "IpSubnets": [
        {
          "AdditionalParams": {},
          "Flags": 3,
          "Health": {
            "LastErrorCode": 0,
            "LastUpdateTime": 133569813606901578
          },
          "ID": "760FAA99-2563-4539-8CD8-57F89695FC7D",
          "IpAddressPrefix": "$($desired_cidr)",
          "ObjectType": 6,
          "Policies": [],
          "State": 0
        }
      ],
      "ObjectType": 5,
      "Policies": [],
      "State": 0
    }
  ],
  "SwitchGuid": "$($id)",
  "SwitchName": "Default Switch",
  "TotalEndpoints": 0,
  "Type": "ICS",
  "Version": 64424509440,
  "Resources": {
    "AdditionalParams": {},
    "AllocationOrder": 2,
    "Allocators": [
      {
        "AdapterNetCfgInstanceId": "{E54B75E2-8E56-443E-BA86-D3384E95F104}",
        "AdditionalParams": {},
        "AllocationOrder": 0,
        "CompartmendId": 0,
        "Connected": true,
        "DNSFirewallRules": true,
        "DeviceInstanceID": "",
        "DevicelessNic": true,
        "DhcpDisabled": true,
        "EndpointNicGuid": "$($id)",
        "EndpointPortGuid": "$($id)",
        "Flags": 0,
        "ID": "6561273D-023A-40A8-85BF-1CDCB5B5D206",
        "InterfaceGuid": "E54B75E2-8E56-443E-BA86-D3384E95F104",
        "IsPolicy": false,
        "IsolationId": 0,
        "MacAddress": "00-15-5D-0F-A0-3B",
        "ManagementPort": true,
        "NcfHidden": false,
        "NetworkId": "$($id)",
        "NicFriendlyName": "Default Switch",
        "NlmHidden": true,
        "PortFriendlyNamePrefix": "Host Vnic",
        "PreferredPortFriendlyName": "Host Vnic $($id)",
        "State": 3,
        "SwitchId": "$($id)",
        "Tag": "Host Vnic",
        "VmPort": false,
        "WaitForIpv6Interface": false,
        "nonPersistentPort": false
      },
      {
        "AdditionalParams": {},
        "AllocationOrder": 1,
        "Dhcp": true,
        "DisableSharing": false,
        "Dns": true,
        "ExternalInterfaceConstraint": 0,
        "Flags": 0,
        "ICSDHCPFlags": 0,
        "ICSFlags": 0,
        "ID": "71660378-052A-4657-8BA1-B8B850C9091F",
        "IsPolicy": false,
        "Prefix": 20,
        "PrivateInterfaceGUID": "E54B75E2-8E56-443E-BA86-D3384E95F104",
        "State": 3,
        "SubnetIPAddress": "172.31.80.0",
        "Tag": "ICS"
      }
    ],
    "CompartmentOperationTime": 0,
    "Flags": 0,
    "ID": "4433905F-F5E1-4453-9B24-EC9C1C00B655",
    "PortOperationTime": 0,
    "State": 1,
    "SwitchOperationTime": 0,
    "VfpOperationTime": 0,
    "parentId": "FDDED980-D10D-442E-B41E-49D9EF46FF3B"
  }
}
"@
        }
    }
    if ($network) {
        log "recreating network with id [$($id)]"
        New-HnsNetworkEx -Id $id -JsonString $network
    }
}

set_network_cidr 'WSL' "192.168.201.248/29" "192.168.201.249"
set_network_cidr 'Default Switch' "192.168.201.240/29" "192.169.201.241"
