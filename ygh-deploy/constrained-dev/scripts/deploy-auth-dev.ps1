[CmdletBinding()]
param(
    [string]$VmHost = "vm-ygh",
    [string]$DatabaseHost = "192.168.154.10",
    [string]$NacosHost = "192.168.154.10",
    [int]$Port = 18081
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
foreach ($required in @(
        "AUTH_DB_APP_PASSWORD", "AUTH_DB_MIGRATION_PASSWORD", "NACOS_ADMIN_PASSWORD")) {
    if ([string]::IsNullOrWhiteSpace($config[$required])) { throw "$required missing" }
}

Push-Location $repositoryRoot
try {
    & .\mvnw.cmd -q -pl ygh-platform/ygh-auth-service -am package -DskipTests
    if ($LASTEXITCODE -ne 0) { throw "Auth package failed" }

    & ssh $VmHost "cd /opt/ygh/constrained-dev && ./scripts/provision-auth-db.sh"
    if ($LASTEXITCODE -ne 0) { throw "Auth DB bootstrap failed" }

    $jar = Join-Path $repositoryRoot "ygh-platform\ygh-auth-service\target\ygh-auth-service-1.0.0-SNAPSHOT.jar"
    $dbUrl = "jdbc:mysql://${DatabaseHost}:3306/auth_db?useUnicode=true&characterEncoding=utf8&serverTimezone=Asia/Shanghai&useSSL=false&allowPublicKeyRetrieval=true"
    $env:YGH_AUTH_DB_URL = $dbUrl
    $env:YGH_AUTH_DB_APP_USERNAME = "ygh_auth_migration"
    $env:YGH_AUTH_DB_APP_PASSWORD = $config.AUTH_DB_MIGRATION_PASSWORD
    $env:YGH_AUTH_DB_MIGRATION_USERNAME = "ygh_auth_migration"
    $env:YGH_AUTH_DB_MIGRATION_PASSWORD = $config.AUTH_DB_MIGRATION_PASSWORD
    $env:YGH_NACOS_SERVER_ADDR = "${NacosHost}:8848"
    $env:YGH_NACOS_USERNAME = "nacos"
    $env:YGH_NACOS_PASSWORD = $config.NACOS_ADMIN_PASSWORD

    & java '-Dloader.main=com.yuegang.zhihui.auth.AuthMigrationApplication' `
        -cp $jar org.springframework.boot.loader.launch.PropertiesLauncher
    if ($LASTEXITCODE -ne 0) { throw "Auth Flyway migration job failed" }

    & ssh $VmHost "cd /opt/ygh/constrained-dev && ./scripts/provision-auth-db.sh && ./scripts/verify-auth-db.sh"
    if ($LASTEXITCODE -ne 0) { throw "Auth DB post-migration grants failed" }

    $env:YGH_AUTH_DB_APP_USERNAME = "ygh_auth_app"
    $env:YGH_AUTH_DB_APP_PASSWORD = $config.AUTH_DB_APP_PASSWORD
    Remove-Item Env:YGH_AUTH_DB_MIGRATION_USERNAME -ErrorAction SilentlyContinue
    Remove-Item Env:YGH_AUTH_DB_MIGRATION_PASSWORD -ErrorAction SilentlyContinue
    $env:YGH_AUTH_PORT = $Port.ToString()
    $stdout = Join-Path (Split-Path $jar) "auth-service.log"
    $stderr = Join-Path (Split-Path $jar) "auth-service-error.log"
    $pidFile = Join-Path (Split-Path $jar) "auth-service.pid"
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
    $listener = Get-NetTCPConnection -State Listen -LocalPort $Port -ErrorAction SilentlyContinue
    if ($listener) { throw "Auth port $Port is already occupied by PID $($listener.OwningProcess)" }

    $process = Start-Process java -ArgumentList '-Xms96m', '-Xmx192m', '-jar', $jar, `
        '--spring.flyway.enabled=false' `
        -RedirectStandardOutput $stdout -RedirectStandardError $stderr `
        -WindowStyle Hidden -PassThru

    foreach ($attempt in 1..45) {
        Start-Sleep -Seconds 1
        $process.Refresh()
        if ($process.HasExited) {
            throw "New Auth process exited before readiness, exitCode=$($process.ExitCode)"
        }
        try {
            $health = Invoke-RestMethod "http://127.0.0.1:$Port/actuator/health/readiness" -TimeoutSec 2
            $owner = Get-NetTCPConnection -State Listen -LocalPort $Port -ErrorAction SilentlyContinue
            if ($health.status -eq "UP" -and $owner.OwningProcess -eq $process.Id) {
                $temporaryPidFile = "$pidFile.tmp"
                Set-Content -LiteralPath $temporaryPidFile -Value $process.Id -Encoding ascii
                Move-Item -LiteralPath $temporaryPidFile -Destination $pidFile -Force
                Write-Output "AUTH_DEPLOYED pid=$($process.Id) port=$Port readiness=UP"
                exit 0
            }
        } catch { }
    }
    Stop-Process -Id $process.Id -Force -ErrorAction SilentlyContinue
    throw "Auth readiness did not become UP"
} finally {
    Pop-Location
}
