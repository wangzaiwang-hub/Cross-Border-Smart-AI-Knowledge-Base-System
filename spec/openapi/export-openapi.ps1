[CmdletBinding()]
param(
    [ValidateSet("docker", "host")][string]$Transport = "docker",
    [string]$GatewayUrl = "http://localhost:8080",
    [string]$ServiceHost = "localhost",
    [string]$ContainerProject = "ygh-apps",
    [string[]]$Services = @(),
    [string]$OutputDirectory = $PSScriptRoot
)

$ErrorActionPreference = "Stop"
$catalog = [ordered]@{
    gateway = 8080; auth = 8081; user = 8082; system = 8083
    product = 8084; inventory = 8085; order = 8086; wallet = 8087
    knowledge = 8088; search = 8089; ai = 8090; training = 8091
    notification = 8092; admin = 8093
}
$selected = if ($Services.Count -eq 0) { @($catalog.Keys) } else { @($Services) }
foreach ($service in $selected) {
    if (-not $catalog.Contains($service)) { throw "Unknown service: $service" }
}

$temporaryDirectory = Join-Path ([System.IO.Path]::GetTempPath()) ("ygh-openapi-" + [guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Force -Path $temporaryDirectory | Out-Null
try {
    foreach ($service in $selected) {
        $port = $catalog[$service]
        $target = Join-Path $temporaryDirectory "$service-service-v1.json"
        if ($Transport -eq "docker") {
            $container = "$ContainerProject-$service-1"
            $content = & docker exec $container wget -qO- "http://127.0.0.1:$port/v3/api-docs"
            if ($LASTEXITCODE -ne 0) { throw "OpenAPI export failed for container $container" }
            [System.IO.File]::WriteAllText($target, [string]::Join("`n", $content), [System.Text.UTF8Encoding]::new($false))
        } else {
            $baseUrl = if ($service -eq "gateway") { $GatewayUrl.TrimEnd("/") } else { "http://${ServiceHost}:$port" }
            Invoke-WebRequest -UseBasicParsing -TimeoutSec 30 -Uri "$baseUrl/v3/api-docs" -OutFile $target
        }
        $document = Get-Content -Raw -LiteralPath $target | ConvertFrom-Json
        if (-not $document.openapi -or -not $document.info -or -not $document.paths) {
            throw "Invalid OpenAPI document returned by $service"
        }
    }

    New-Item -ItemType Directory -Force -Path $OutputDirectory | Out-Null
    foreach ($file in Get-ChildItem -LiteralPath $temporaryDirectory -Filter "*-service-v1.json") {
        Move-Item -Force -LiteralPath $file.FullName -Destination (Join-Path $OutputDirectory $file.Name)
    }
    Write-Host "OPENAPI_EXPORT_OK count=$($selected.Count) transport=$Transport services=$($selected -join ',')"
}
finally {
    Remove-Item -Recurse -Force -LiteralPath $temporaryDirectory -ErrorAction SilentlyContinue
}
