$ErrorActionPreference = 'Stop'

$ruleName = 'YGH-VM-to-Local-Docker'
$ports = @('7091', '8091', '9200', '9876', '10909', '10911', '10912')
$backupRoot = Join-Path $env:USERPROFILE '.ygh-backup'
New-Item -ItemType Directory -Path $backupRoot -Force | Out-Null
$logPath = Join-Path $backupRoot 'configure-ygh-firewall.log'

Start-Transcript -LiteralPath $logPath -Force | Out-Null
try {
    Get-NetFirewallRule -DisplayName $ruleName -ErrorAction SilentlyContinue | Remove-NetFirewallRule
    New-NetFirewallRule `
        -DisplayName $ruleName `
        -Direction Inbound `
        -Action Allow `
        -Protocol TCP `
        -LocalAddress 192.168.154.1 `
        -LocalPort $ports `
        -RemoteAddress 192.168.154.0/24 `
        -Profile Any | Out-Null

    Write-Output "FIREWALL_OK rule=$ruleName remote=192.168.154.0/24 ports=$($ports -join ',')"
} finally {
    Stop-Transcript | Out-Null
}
