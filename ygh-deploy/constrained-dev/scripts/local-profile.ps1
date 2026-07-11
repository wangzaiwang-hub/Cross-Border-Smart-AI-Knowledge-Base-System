param(
    [Parameter(Mandatory = $true)]
    [ValidateSet('mall-deps', 'ai-deps', 'stop', 'status')]
    [string]$Mode
)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
Set-Location $root
$compose = @('compose', '--env-file', '.env', '-f', 'local-compose.yml')

function Assert-DockerReady {
    & docker info *> $null
    if ($LASTEXITCODE -ne 0) {
        throw 'Docker Desktop is not ready.'
    }
}

function Get-FreeMemoryMB {
    $os = Get-CimInstance Win32_OperatingSystem
    return [math]::Round($os.FreePhysicalMemory / 1024)
}

function Get-ForeignContainers {
    $foreign = @()
    foreach ($id in @(& docker ps --quiet)) {
        $metadata = @(& docker inspect $id | ConvertFrom-Json)[0]
        $name = $metadata.Name.TrimStart('/')
        $project = $metadata.Config.Labels.'com.docker.compose.project'
        if ($name -and $project -ne 'ygh-local') {
            $foreign += $name
        }
    }
    return $foreign
}

function Stop-YghProfiles {
    & docker @compose --profile mall-deps --profile ai-deps stop
    if ($LASTEXITCODE -ne 0) { throw 'Failed to stop YGH local profiles.' }
}

function Wait-ProfileHealthy([string]$profile) {
    $targets = if ($profile -eq 'mall-deps') {
        @(
            'ygh-local-rocketmq-namesrv-1',
            'ygh-local-rocketmq-broker-1',
            'ygh-local-seata-1'
        )
    } else {
        @('ygh-local-elasticsearch-1')
    }

    $deadline = (Get-Date).AddMinutes(3)
    do {
        $ready = $true
        foreach ($container in $targets) {
            $state = & docker inspect --format '{{.State.Status}}/{{if .State.Health}}{{.State.Health.Status}}{{else}}none{{end}}' $container 2>$null
            if ($LASTEXITCODE -ne 0 -or $state -ne 'running/healthy') {
                $ready = $false
                break
            }
        }
        if ($ready) { return }
        Start-Sleep -Seconds 5
    } while ((Get-Date) -lt $deadline)

    & docker @compose --profile $profile ps
    throw "Profile $profile did not become healthy within 180 seconds."
}

Assert-DockerReady

if ($Mode -eq 'status') {
    & docker @compose --profile mall-deps --profile ai-deps ps
    & docker stats --no-stream
    Write-Output "WINDOWS_FREE_MB=$(Get-FreeMemoryMB)"
    exit 0
}

if ($Mode -eq 'stop') {
    Stop-YghProfiles
    Write-Output 'YGH_LOCAL_PROFILES_STOPPED_VOLUMES_PRESERVED'
    exit 0
}

$foreign = Get-ForeignContainers
if ($foreign.Count -gt 0) {
    throw "Refusing to start $Mode while other Docker projects are running: $($foreign -join ', ')"
}

Stop-YghProfiles
Start-Sleep -Seconds 5
$freeBefore = Get-FreeMemoryMB
if ($freeBefore -lt 2200) {
    throw "Refusing to start $Mode because Windows free memory is ${freeBefore}MB (<2200MB)."
}

& docker @compose --profile $Mode up -d
if ($LASTEXITCODE -ne 0) { throw "Failed to start $Mode." }
Wait-ProfileHealthy $Mode

$freeAfter = Get-FreeMemoryMB
if ($freeAfter -lt 2000) {
    Stop-YghProfiles
    throw "Stopped $Mode because Windows free memory fell to ${freeAfter}MB (<2000MB)."
}

Write-Output "PROFILE_HEALTH_OK profile=$Mode windows_free_mb=$freeAfter"
