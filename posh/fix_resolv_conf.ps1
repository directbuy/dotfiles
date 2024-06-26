# Before attempting to run this script, review and/or follow the
# following steps.
#
# 0. Make sure you can execute powershell scripts. Start Powershell as an
#    administrator and execute:
#
#      Set-ExecutionPolicy RemoteSigned
#
# 1. Make sure you disable wsl's broken resolv.conf handler.
#    Create /etc/wsl.conf with the following 2 lines (without the pound signs):
#
#      [network]
#      generateResolvConf = false
#
#    After that, make sure you issue a wsl.exe --shutdown.
#
# 2. Configure your WSL distro name in $WslDistroName below (do wsl -l to
#    see your distro names) and make sure we're pointing at your resolv.conf
#    file in $ResolvConfFile. Also make sure we can write to the resolv.conf
#    file. I had to set permissions pretty broadly at 666 (chmod 666 /etc/resolv.conf).
#
# 3. Schedule this script with Task Scheduler:
#
#      * Click Action �> Create Task�
#      * Give your task a name in the General tab
#      * Click on the Triggers tab and then click New�
#      * In the "Begin the task" menu, choose �On an event.� Then, choose:
#
#          Log: Microsoft-Windows-NetworkProfile/Operational
#          Source: NetworkProfile
#          Event ID: 10000
#
#      * Event ID 10000 is logged when you connect to a network. Add another
#        one when a disconnect would occur (Event ID 10001):
#
#          Log: Microsoft-Windows-NetworkProfile/Operational
#          Source: NetworkProfile
#          Event ID: 10001
#
#      * Go to the Conditions tab. Make sure it runs regardless of AC adapter
#        connected/disconnected, peruse the other options there.
#
#      * Go to the Actions tab. Add a run script action and then:
#
#          Program/script: powershell.exe
#          Arguments: -NoProfile -File "c:\where\you\stored\wsl-resolv-handler.ps1"
#
#      * Optionally add -WindowStyle Hidden to above Arguments.
[CmdletBinding()]
param(
  [Parameter()][boolean]$install=$false
)
if ($install) {
    Write-Host "installing"
    $trigger_class = Get-CimClass -ClassName MSFT_TaskEventTrigger `
        -Namespace Root/Microsoft/Windows/TaskScheduler:MSFT_TaskEventTrigger
    $trigger = New-CimInstance -CimClass $trigger_class -ClientOnly
    $trigger.Subscription =
@"
<QueryList>
  <Query Id="0" Path="Microsoft-Windows-NetworkProfile/Operational">
    <Select Path="Microsoft-Windows-NetworkProfile/Operational">
      *[System[(EventID=10000) or (EventID=10001)]]
    </Select>
  </Query>
</QueryList>
"@
    $trigger.Enabled = $True
    $action = New-ScheduledTaskAction `
        -execute 'powershell.exe' `
        -argument "-NoProfile -File $($myinvocation.mycommand.path)"
    $settings = New-ScheduledTaskSettingsSet `
        -AllowStartIfOnBatteries:$true `
        -DontStopIfGoingOnBatteries:$true
    $task = New-ScheduledTask `
        -Action $action `
        -Settings $settings `
        -trigger $trigger
    register-scheduledtask fix_resolv_conf -InputObject $task
    exit
}
$distro = "focal"

# Discover things and create an $Entries object.
$NetworkInterfaces  = Get-NetIPInterface -AddressFamily IPv4 | Where-Object ConnectionState -EQ 'Connected' | Where-Object NlMtu -LT 9001
$DNSServerAddresses = Get-DnsClientServerAddress -AddressFamily IPv4
$DNSClients = Get-DnsClient

$Entries = $NetworkInterfaces | ForEach-Object {
  [PSCustomObject]@{
    'InterfaceAlias'      = $_.InterfaceAlias
    'InterfaceIndex'      = $_.InterfaceIndex
    'InterfaceMetric'     = $_.InterfaceMetric
    'DNSServerAddresses'  = ($DNSServerAddresses | Where-Object InterfaceIndex -EQ $_.InterfaceIndex | Where-Object AddressFamily -EQ 2).ServerAddresses
    'DNSSuffixes'  =  @(($DNSClients | Where-Object InterfaceIndex -EQ $_.InterfaceIndex).ConnectionSpecificSuffix) + @(($DNSClients).ConnectionSpecificSuffixSearchList | Out-Null)
  }
} | Sort-Object InterfaceMetric -Unique

# Tell the console what we found.
Write-Output ([string]::Format("    DNS servers configured: {0}", ($Entries.DNSServerAddresses -join ",")))
if ($Entries.DNSSuffixes -gt 0) {
    Write-Output ([string]::Format("Search suffixes configured: {0}", ($Entries.DNSSuffixes -join ",")))
}

# Writing resolv.conf with things discovered.
$CommentLine = [string]::Format("# Generated by wsl-resolv-handler.ps1.")
# Write-Output $CommentLine | Set-Content -Path $ResolvConfFile
if ($Entries.DNSSuffixes -gt 0) {
    $SearchLine = [string]::Format("search {0}", ($Entries.DNSSuffixes -join " "))
}
# Write-Output $SearchLine | Add-Content -Path $ResolvConfFile
$dns_servers = [system.collections.arraylist]@()
foreach ($entry in $entries) {
    foreach ($dns_server in $entry.DNSServerAddresses) {
        $dns_servers.add([string]::Format("nameserver {0}", $dns_Server))
    }
}
$nameservers = $dns_servers -join "\n"
&wsl.exe -d $distro -u root --exec /bin/bash -c "printf '${CommentLine}\n${SearchLine}\n${nameservers}\n' | tee /etc/resolv.conf"


# SIG # Begin signature block
# MIITjwYJKoZIhvcNAQcCoIITgDCCE3wCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQU1uaTWrZUyWgSTvi5xF685lV7
# OkegghDGMIIFRDCCBCygAwIBAgIRAPObRmxze0JQ5eGP2ElORJ8wDQYJKoZIhvcN
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
# hkiG9w0BCQQxFgQUt1+UVvjtoBQ4s9RUI6FJYREn2ykwDQYJKoZIhvcNAQEBBQAE
# ggEAnl/VZu0tO/ijMrimViCO80myHQe2IWQDb97KAEzTDWtlUXKg3TzDKwO+Re9S
# V69ZsxQ7177uhq4jJeyrLVHXCG4hCCJXAlfr1+SmR7XJIWs0whzMrhSh+VPfc4I1
# QqO9cK7+s1zxph8YMkYn0Jd7IrFsLxiJ2/GM7JGdbrsjZuifRFz0vdsMBn0b1LtZ
# /VIh3ptVoKenEiL3FqHzOLICPFMnL1qMewqCVdry7zqkJEzRP2u+wVmjkqTuRoDc
# hnFqcAxsrLzOhXW8c28SHiWv31oWxei7C94IfApc43I/HKC4VKbVB7wt1yQfLT+e
# YTMPhw5PNVnc3W4zaBD7tGbHqg==
# SIG # End signature block