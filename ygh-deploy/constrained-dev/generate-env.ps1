$ErrorActionPreference = 'Stop'

function New-Secret([int]$bytes = 32) {
    $buffer = New-Object byte[] $bytes
    [System.Security.Cryptography.RandomNumberGenerator]::Fill($buffer)
    return [Convert]::ToBase64String($buffer).TrimEnd('=').Replace('+', 'A').Replace('/', 'B')
}
function New-Base64Secret([int]$bytes = 32) {
    $buffer = New-Object byte[] $bytes
    [System.Security.Cryptography.RandomNumberGenerator]::Fill($buffer)
    return [Convert]::ToBase64String($buffer)
}

$envPath = Join-Path $PSScriptRoot '.env'
if (Test-Path $envPath) {
    $existing = Get-Content -Raw -LiteralPath $envPath
    $updated = $false
    if ($existing -notmatch '(?m)^AUTH_AUDIT_PEPPER_BASE64=') {
        Add-Content -LiteralPath $envPath -Value "AUTH_AUDIT_PEPPER_BASE64=$(New-Secret 32)" -Encoding UTF8NoBOM
        $updated = $true
    }
    if ($existing -notmatch '(?m)^INTERNAL_REQUEST_HMAC_BASE64=') {
        Add-Content -LiteralPath $envPath -Value "INTERNAL_REQUEST_HMAC_BASE64=$(New-Secret 32)" -Encoding UTF8NoBOM
        $updated = $true
    }
    if ($existing -notmatch '(?m)^AUTH_ID_WORKER=') {
        Add-Content -LiteralPath $envPath -Value "AUTH_ID_WORKER=1" -Encoding UTF8NoBOM
        $updated = $true
    }
    if ($existing -notmatch '(?m)^USER_DB_APP_PASSWORD=') {
        Add-Content -LiteralPath $envPath -Value "USER_DB_APP_PASSWORD=$(New-Secret 24)" -Encoding UTF8NoBOM
        $updated = $true
    }
    if ($existing -notmatch '(?m)^USER_DB_MIGRATION_PASSWORD=') {
        Add-Content -LiteralPath $envPath -Value "USER_DB_MIGRATION_PASSWORD=$(New-Secret 24)" -Encoding UTF8NoBOM
        $updated = $true
    }
    if ($existing -notmatch '(?m)^USER_PII_KEY_BASE64=') {
        Add-Content -LiteralPath $envPath -Value "USER_PII_KEY_BASE64=$(New-Base64Secret 32)" -Encoding UTF8NoBOM
        $updated = $true
    }
    if ($existing -notmatch '(?m)^USER_PII_KEY_VERSION=') { Add-Content -LiteralPath $envPath -Value "USER_PII_KEY_VERSION=1" -Encoding UTF8NoBOM; $updated = $true }
    if ($existing -notmatch '(?m)^USER_ID_WORKER=') { Add-Content -LiteralPath $envPath -Value "USER_ID_WORKER=2" -Encoding UTF8NoBOM; $updated = $true }
    if ($existing -notmatch '(?m)^SYSTEM_DB_APP_PASSWORD=') { Add-Content -LiteralPath $envPath -Value "SYSTEM_DB_APP_PASSWORD=$(New-Secret 24)" -Encoding UTF8NoBOM; $updated = $true }
    if ($existing -notmatch '(?m)^SYSTEM_DB_MIGRATION_PASSWORD=') { Add-Content -LiteralPath $envPath -Value "SYSTEM_DB_MIGRATION_PASSWORD=$(New-Secret 24)" -Encoding UTF8NoBOM; $updated = $true }
    Write-Output $(if ($updated) { 'ENV_UPDATED_MISSING_VALUES_HIDDEN' } else { 'ENV_EXISTS_NO_CHANGE' })
    exit 0
}

$tokenBytes = New-Object byte[] 48
[System.Security.Cryptography.RandomNumberGenerator]::Fill($tokenBytes)
$nacosToken = [Convert]::ToBase64String($tokenBytes)

@"
MYSQL_ROOT_PASSWORD=$(New-Secret 24)
NACOS_DB_PASSWORD=$(New-Secret 24)
AUTH_DB_APP_PASSWORD=$(New-Secret 24)
AUTH_DB_MIGRATION_PASSWORD=$(New-Secret 24)
USER_DB_APP_PASSWORD=$(New-Secret 24)
USER_DB_MIGRATION_PASSWORD=$(New-Secret 24)
USER_PII_KEY_BASE64=$(New-Base64Secret 32)
USER_PII_KEY_VERSION=1
USER_ID_WORKER=2
SYSTEM_DB_APP_PASSWORD=$(New-Secret 24)
SYSTEM_DB_MIGRATION_PASSWORD=$(New-Secret 24)
AUTH_AUDIT_PEPPER_BASE64=$(New-Secret 32)
AUTH_ID_WORKER=1
INTERNAL_REQUEST_HMAC_BASE64=$(New-Secret 32)
REDIS_PASSWORD=$(New-Secret 24)
NACOS_AUTH_TOKEN=$nacosToken
NACOS_AUTH_IDENTITY_KEY=ygh-server-$(New-Secret 12)
NACOS_AUTH_IDENTITY_VALUE=$(New-Secret 24)
NACOS_ADMIN_PASSWORD=$(New-Secret 24)
POSTGRES_PASSWORD=$(New-Secret 24)
ELASTIC_PASSWORD=$(New-Secret 24)
SEATA_PASSWORD=$(New-Secret 24)
"@ | Set-Content -LiteralPath $envPath -Encoding UTF8NoBOM

$sid = [System.Security.Principal.WindowsIdentity]::GetCurrent().User.Value
& icacls $envPath /inheritance:r /grant:r "*$sid`:(F)" '*S-1-5-18:(F)' '*S-1-5-32-544:(F)' | Out-Null

Write-Output 'ENV_CREATED_VALUES_HIDDEN'
