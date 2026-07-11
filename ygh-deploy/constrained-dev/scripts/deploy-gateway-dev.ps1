[CmdletBinding()]
param(
    [string]$InfrastructureHost = "192.168.154.10",
    [string]$AdvertiseIp = "192.168.154.1",
    [string]$JwtIssuer = "http://192.168.154.1:18081",
    [string]$JwkSetUri = "http://192.168.154.1:18081/.well-known/jwks.json",
    [int]$Port = 18080
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
$composeDir = Split-Path -Parent $PSScriptRoot
$repositoryRoot = Resolve-Path (Join-Path $composeDir "..\..")
$envFile = Join-Path $composeDir ".env"
if (-not (Test-Path $envFile)) { throw ".env missing" }
$config = @{}
Get-Content -LiteralPath $envFile | ForEach-Object {
    if ($_ -match '^([^#=]+)=(.*)$') { $config[$matches[1]] = $matches[2] }
}
foreach ($required in @("NACOS_ADMIN_PASSWORD", "REDIS_PASSWORD", "INTERNAL_REQUEST_HMAC_BASE64")) {
    if ([string]::IsNullOrWhiteSpace($config[$required])) { throw "$required missing" }
}

Push-Location $repositoryRoot
try {
    & .\mvnw.cmd -q -pl ygh-platform/ygh-gateway -am package -DskipTests
    if ($LASTEXITCODE -ne 0) { throw "Gateway package failed" }
    $jar = Join-Path $repositoryRoot "ygh-platform\ygh-gateway\target\ygh-gateway-1.0.0-SNAPSHOT.jar"
    $env:YGH_NACOS_SERVER_ADDR = "${InfrastructureHost}:8848"
    $env:YGH_NACOS_USERNAME = "nacos"
    $env:YGH_NACOS_PASSWORD = $config.NACOS_ADMIN_PASSWORD
    $env:YGH_NACOS_NAMESPACE = "ygh-dev"
    $env:YGH_SERVICE_IP = $AdvertiseIp
    $env:YGH_REDIS_HOST = $InfrastructureHost
    $env:YGH_REDIS_PORT = "6379"
    $env:YGH_REDIS_PASSWORD = $config.REDIS_PASSWORD
    $env:YGH_REDIS_ENVIRONMENT = "dev"
    $env:YGH_GATEWAY_SESSION_VALIDATION_ENABLED = "true"
    $env:YGH_JWT_ISSUER = $JwtIssuer
    $env:YGH_JWT_JWK_SET_URI = $JwkSetUri
    $env:YGH_GATEWAY_CORS_ALLOWED_ORIGINS = "http://127.0.0.1:5173"
    $env:YGH_GATEWAY_PORT = $Port.ToString()
    $env:YGH_INTERNAL_REQUEST_HMAC_BASE64 = $config.INTERNAL_REQUEST_HMAC_BASE64

    $target = Split-Path $jar
    $stdout = Join-Path $target "gateway.log"
    $stderr = Join-Path $target "gateway-error.log"
    $pidFile = Join-Path $target "gateway.pid"
    if (Test-Path $pidFile) {
        $previousPid = 0
        if ([int]::TryParse((Get-Content $pidFile -Raw).Trim(), [ref]$previousPid)) {
            $previous = Get-CimInstance Win32_Process -Filter "ProcessId=$previousPid" -ErrorAction SilentlyContinue
            if ($previous -and $previous.Name -eq "java.exe" -and
                $previous.CommandLine -like "*$([IO.Path]::GetFileName($jar))*") {
                Stop-Process -Id $previousPid -ErrorAction Stop
                Wait-Process -Id $previousPid -Timeout 20 -ErrorAction SilentlyContinue
            }
        }
        Remove-Item $pidFile -Force
    }
    if (Get-NetTCPConnection -State Listen -LocalPort $Port -ErrorAction SilentlyContinue) {
        throw "Gateway port $Port is already occupied"
    }
    $process = Start-Process java -ArgumentList '-Xms96m', '-Xmx192m', '-jar', $jar `
        -RedirectStandardOutput $stdout -RedirectStandardError $stderr -WindowStyle Hidden -PassThru
    foreach ($attempt in 1..45) {
        Start-Sleep -Seconds 1
        $process.Refresh()
        if ($process.HasExited) { throw "Gateway exited before readiness, exitCode=$($process.ExitCode)" }
        try {
            $health = Invoke-RestMethod "http://127.0.0.1:$Port/readyz" -TimeoutSec 2
            if ($health.status -eq "UP") {
                Set-Content -LiteralPath "$pidFile.tmp" -Value $process.Id -Encoding ascii
                Move-Item -LiteralPath "$pidFile.tmp" -Destination $pidFile -Force
                Write-Output "GATEWAY_DEPLOYED pid=$($process.Id) port=$Port readiness=UP redisSessionValidation=true"
                exit 0
            }
        } catch { }
    }
    Stop-Process -Id $process.Id -Force -ErrorAction SilentlyContinue
    throw "Gateway readiness did not become UP"
} finally {
    Pop-Location
}
