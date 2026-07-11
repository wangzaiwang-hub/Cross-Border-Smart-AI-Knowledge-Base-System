[CmdletBinding()]
param(
    [string]$GatewayBaseUrl = "http://127.0.0.1:18080",
    [string]$NacosBaseUrl = "http://192.168.154.10:8848",
    [string]$NamespaceId = "ygh-dev",
    [string]$GroupName = "YGH_GROUP",
    [string]$ServiceName = "ygh-gateway",
    [string]$ExpectedIp = "192.168.154.1",
    [int]$ExpectedPort = 18080
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

if ([string]::IsNullOrWhiteSpace($env:YGH_NACOS_USERNAME) -or
    [string]::IsNullOrWhiteSpace($env:YGH_NACOS_PASSWORD)) {
    throw "YGH_NACOS_USERNAME and YGH_NACOS_PASSWORD must be injected as environment variables."
}

$readiness = Invoke-RestMethod -Uri "$GatewayBaseUrl/readyz" -TimeoutSec 5
if ($readiness.status -ne "UP") {
    throw "Gateway readiness is not UP."
}

$login = Invoke-RestMethod `
    -Method Post `
    -Uri "$NacosBaseUrl/nacos/v3/auth/user/login" `
    -Body @{ username = $env:YGH_NACOS_USERNAME; password = $env:YGH_NACOS_PASSWORD } `
    -ContentType "application/x-www-form-urlencoded" `
    -TimeoutSec 5
$accessToken = if ($login.accessToken) { $login.accessToken } else { $login.data.accessToken }
if ([string]::IsNullOrWhiteSpace($accessToken)) {
    throw "Nacos login did not return an access token."
}

$query = "$NacosBaseUrl/nacos/v3/admin/ns/instance/list" +
    "?serviceName=$([uri]::EscapeDataString($ServiceName))" +
    "&groupName=$([uri]::EscapeDataString($GroupName))" +
    "&namespaceId=$([uri]::EscapeDataString($NamespaceId))" +
    "&accessToken=$([uri]::EscapeDataString($accessToken))"
$matches = @()
foreach ($attempt in 1..30) {
    try {
        $response = Invoke-RestMethod -Uri $query -TimeoutSec 5
        $hosts = @()
        if ($response.PSObject.Properties.Name -contains "data") {
            if ($response.data -is [array]) {
                $hosts = $response.data
            } elseif ($response.data.PSObject.Properties.Name -contains "hosts") {
                $hosts = $response.data.hosts
            }
        } elseif ($response.PSObject.Properties.Name -contains "hosts") {
            $hosts = $response.hosts
        }
        $matches = @($hosts | Where-Object {
            $_.ip -eq $ExpectedIp -and
            [int]$_.port -eq $ExpectedPort -and
            $_.healthy -eq $true -and
            $_.enabled -ne $false
        })
        if ($matches.Count -eq 1) {
            break
        }
    } catch {
        # Readiness can become UP shortly before the asynchronous Nacos registration completes.
    }
    Start-Sleep -Milliseconds 500
}
if ($matches.Count -ne 1) {
    throw "Expected exactly one healthy Gateway instance, found $($matches.Count)."
}

Write-Output "GATEWAY_REGISTRATION_OK service=$GroupName@@$ServiceName instance=$ExpectedIp`:$ExpectedPort readiness=UP"
