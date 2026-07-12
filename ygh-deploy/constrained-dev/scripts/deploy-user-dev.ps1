[CmdletBinding()]
param(
    [string]$VmHost = "vm-ygh",
    [string]$DatabaseHost = "192.168.154.10",
    [string]$NacosHost = "192.168.154.10",
    [string]$AdvertiseIp = "192.168.154.1",
    [int]$Port = 18082
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
foreach ($required in @("USER_DB_APP_PASSWORD", "USER_DB_MIGRATION_PASSWORD", "NACOS_ADMIN_PASSWORD")) {
    if ([string]::IsNullOrWhiteSpace($config[$required])) { throw "$required missing" }
}
Push-Location $repositoryRoot
try {
    & .\mvnw.cmd -q -pl ygh-applications/ygh-user/ygh-user-service -am package -DskipTests
    if ($LASTEXITCODE -ne 0) { throw "User package failed" }
    & ssh $VmHost "cd /opt/ygh/constrained-dev && ./scripts/provision-user-db.sh"
    if ($LASTEXITCODE -ne 0) { throw "User DB bootstrap failed" }
    $buildJar = Join-Path $repositoryRoot "ygh-applications\ygh-user\ygh-user-service\target\ygh-user-service-1.0.0-SNAPSHOT.jar"
    $env:YGH_USER_DB_URL = "jdbc:mysql://${DatabaseHost}:3306/user_db?useUnicode=true&characterEncoding=utf8&serverTimezone=Asia/Shanghai&useSSL=false&allowPublicKeyRetrieval=true"
    $env:YGH_USER_DB_APP_USERNAME = "ygh_user_migration"
    $env:YGH_USER_DB_APP_PASSWORD = $config.USER_DB_MIGRATION_PASSWORD
    $env:YGH_USER_DB_MIGRATION_USERNAME = "ygh_user_migration"
    $env:YGH_USER_DB_MIGRATION_PASSWORD = $config.USER_DB_MIGRATION_PASSWORD
    $env:YGH_NACOS_SERVER_ADDR = "${NacosHost}:8848"
    $env:YGH_NACOS_USERNAME = "nacos"
    $env:YGH_NACOS_PASSWORD = $config.NACOS_ADMIN_PASSWORD
    $env:YGH_USER_ADVERTISE_IP = $AdvertiseIp
    & java '-Dloader.main=com.yuegang.zhihui.user.UserMigrationApplication' `
        -cp $buildJar org.springframework.boot.loader.launch.PropertiesLauncher
    if ($LASTEXITCODE -ne 0) { throw "User Flyway migration job failed" }
    & ssh $VmHost "cd /opt/ygh/constrained-dev && ./scripts/provision-user-db.sh && ./scripts/verify-user-db.sh"
    if ($LASTEXITCODE -ne 0) { throw "User DB post-migration verification failed" }
    $env:YGH_USER_DB_APP_USERNAME = "ygh_user_app"
    $env:YGH_USER_DB_APP_PASSWORD = $config.USER_DB_APP_PASSWORD
    Remove-Item Env:YGH_USER_DB_MIGRATION_USERNAME -ErrorAction SilentlyContinue
    Remove-Item Env:YGH_USER_DB_MIGRATION_PASSWORD -ErrorAction SilentlyContinue
    $env:YGH_USER_PORT = $Port.ToString()
    $runtimeDirectory = Join-Path $composeDir "runtime\user"
    New-Item -ItemType Directory -Path $runtimeDirectory -Force | Out-Null
    $runtimeJar = Join-Path $runtimeDirectory "ygh-user-service.jar"
    $nextJar = Join-Path $runtimeDirectory "ygh-user-service.jar.next"
    Copy-Item -LiteralPath $buildJar -Destination $nextJar -Force
    $pidFile = Join-Path $runtimeDirectory "user-service.pid"
    if (Test-Path $pidFile) {
        $previousPid = 0
        if ([int]::TryParse((Get-Content $pidFile -Raw).Trim(), [ref]$previousPid)) {
            $previous = Get-CimInstance Win32_Process -Filter "ProcessId=$previousPid" -ErrorAction SilentlyContinue
            if ($previous -and $previous.Name -eq "java.exe" -and
                $previous.CommandLine -like "*$([IO.Path]::GetFileName($runtimeJar))*") {
                Stop-Process -Id $previousPid -ErrorAction Stop
                Wait-Process -Id $previousPid -Timeout 20 -ErrorAction SilentlyContinue
            }
        }
        Remove-Item $pidFile -Force
    }
    if (Get-NetTCPConnection -State Listen -LocalPort $Port -ErrorAction SilentlyContinue) {
        throw "User port $Port is already occupied"
    }
    Move-Item -LiteralPath $nextJar -Destination $runtimeJar -Force
    $process = Start-Process java -ArgumentList '-Xms96m','-Xmx192m','-jar',$runtimeJar,'--spring.flyway.enabled=false' `
        -RedirectStandardOutput (Join-Path $runtimeDirectory "user-service.log") `
        -RedirectStandardError (Join-Path $runtimeDirectory "user-service-error.log") -WindowStyle Hidden -PassThru
    foreach ($attempt in 1..45) {
        Start-Sleep -Seconds 1
        $process.Refresh()
        if ($process.HasExited) { throw "User exited before readiness, exitCode=$($process.ExitCode)" }
        try {
            $health = Invoke-RestMethod "http://127.0.0.1:$Port/actuator/health/readiness" -TimeoutSec 2
            $owner = Get-NetTCPConnection -State Listen -LocalPort $Port -ErrorAction SilentlyContinue
            if ($health.status -eq "UP" -and $owner.OwningProcess -eq $process.Id) {
                Set-Content -LiteralPath "$pidFile.tmp" -Value $process.Id -Encoding ascii
                Move-Item -LiteralPath "$pidFile.tmp" -Destination $pidFile -Force
                Write-Output "USER_DEPLOYED pid=$($process.Id) port=$Port readiness=UP"
                exit 0
            }
        } catch { }
    }
    Stop-Process -Id $process.Id -Force -ErrorAction SilentlyContinue
    throw "User readiness did not become UP"
} finally { Pop-Location }
