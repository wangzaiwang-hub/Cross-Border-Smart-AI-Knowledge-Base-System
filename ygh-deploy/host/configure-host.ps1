$ErrorActionPreference = 'Stop'

$timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$workspace = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$template = Join-Path $PSScriptRoot 'wslconfig.template'
$wslConfig = Join-Path $HOME '.wslconfig'
$dockerSettings = Join-Path $env:APPDATA 'Docker\settings-store.json'

if (Test-Path $wslConfig) {
    Copy-Item -LiteralPath $wslConfig -Destination "$wslConfig.bak-$timestamp"
}
Copy-Item -LiteralPath $template -Destination $wslConfig -Force

if (Test-Path $dockerSettings) {
    Copy-Item -LiteralPath $dockerSettings -Destination "$dockerSettings.bak-$timestamp"
    $settings = Get-Content -Raw -LiteralPath $dockerSettings | ConvertFrom-Json
    $settings.AutoStart = $false
    $settings.EnableDockerAI = $false
    $settings.InferenceCanUseGPUVariant = $false
    $settings | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $dockerSettings -Encoding UTF8
}

# Docker Desktop 的 WSL 代理运行在已集成发行版中。直接 shutdown/terminate
# 会触发集成错误，必须先让 Docker Desktop 正常停止。
docker desktop status *> $null
if ($LASTEXITCODE -eq 0) {
    docker desktop stop
    if ($LASTEXITCODE -ne 0) {
        throw 'Docker Desktop did not stop cleanly; WSL was not shut down.'
    }
}
wsl --shutdown

Write-Output 'HOST_CONFIG_OK'
Write-Output 'WSL2 memory=3GB processors=4 swap=1GB'
Write-Output 'Docker Desktop autostart=false DockerAI=false'
