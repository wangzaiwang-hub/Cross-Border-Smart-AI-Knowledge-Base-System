$ErrorActionPreference = 'Stop'

$principal = New-Object Security.Principal.WindowsPrincipal(
    [Security.Principal.WindowsIdentity]::GetCurrent()
)
if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    throw 'This script must run as Administrator.'
}

$backupRoot = Join-Path $env:USERPROFILE '.ygh-backup'
New-Item -ItemType Directory -Path $backupRoot -Force | Out-Null
$timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$logPath = Join-Path $backupRoot "enable-wsl2-$timestamp.log"

Start-Transcript -LiteralPath $logPath -Force | Out-Null
try {
    foreach ($featureName in @(
        'Microsoft-Windows-Subsystem-Linux',
        'VirtualMachinePlatform'
    )) {
        $feature = Get-WindowsOptionalFeature -Online -FeatureName $featureName
        Write-Output "FEATURE_BEFORE $featureName=$($feature.State)"
        if ($feature.State -ne 'Enabled') {
            Enable-WindowsOptionalFeature -Online -FeatureName $featureName -All -NoRestart | Out-Null
        }
        $feature = Get-WindowsOptionalFeature -Online -FeatureName $featureName
        Write-Output "FEATURE_AFTER $featureName=$($feature.State)"
    }

    bcdedit.exe /enum current | Out-File -LiteralPath (Join-Path $backupRoot "bcd-current-before-$timestamp.txt") -Encoding utf8
    bcdedit.exe /set hypervisorlaunchtype auto | Out-Null
    if ($LASTEXITCODE -ne 0) {
        throw "bcdedit failed with exit code $LASTEXITCODE"
    }

    Write-Output 'WSL2_FEATURES_ENABLED_REBOOT_REQUIRED'
    Write-Output "LOG=$logPath"
} finally {
    Stop-Transcript | Out-Null
}
