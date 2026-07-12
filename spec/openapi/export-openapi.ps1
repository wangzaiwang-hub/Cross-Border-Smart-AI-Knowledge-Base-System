[CmdletBinding()]
param(
    [string]$GatewayUrl = "http://localhost:8080",
    [string]$ServiceHost = "localhost",
    [string]$OutputDirectory = $PSScriptRoot
)

$ErrorActionPreference = "Stop"
$services = [ordered]@{
    gateway = 8080; auth = 8081; user = 8082; system = 8083
    product = 8084; inventory = 8085; order = 8086; wallet = 8087
    knowledge = 8088; search = 8089; ai = 8090; training = 8091
    notification = 8092; admin = 8093
}
$temporaryDirectory = Join-Path ([System.IO.Path]::GetTempPath()) ("ygh-openapi-" + [guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Force -Path $temporaryDirectory | Out-Null

try {
    foreach ($entry in $services.GetEnumerator()) {
        $baseUrl = if ($entry.Key -eq "gateway") { $GatewayUrl.TrimEnd("/") } else { "http://${ServiceHost}:$($entry.Value)" }
        $target = Join-Path $temporaryDirectory "$($entry.Key)-service-v1.json"
        Invoke-WebRequest -UseBasicParsing -TimeoutSec 30 -Uri "$baseUrl/v3/api-docs" -OutFile $target
        $document = Get-Content -Raw -LiteralPath $target | ConvertFrom-Json
        if (-not $document.openapi -or -not $document.info -or -not $document.paths) {
            throw "Invalid OpenAPI document returned by $($entry.Key)"
        }
    }

    New-Item -ItemType Directory -Force -Path $OutputDirectory | Out-Null
    foreach ($file in Get-ChildItem -LiteralPath $temporaryDirectory -Filter "*-service-v1.json") {
        Move-Item -Force -LiteralPath $file.FullName -Destination (Join-Path $OutputDirectory $file.Name)
    }
    Write-Host "Exported $($services.Count) validated OpenAPI documents to $OutputDirectory"
}
finally {
    Remove-Item -Recurse -Force -LiteralPath $temporaryDirectory -ErrorAction SilentlyContinue
}
