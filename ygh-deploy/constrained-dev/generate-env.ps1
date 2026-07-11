$ErrorActionPreference = 'Stop'

function New-Secret([int]$bytes = 32) {
    $buffer = New-Object byte[] $bytes
    [System.Security.Cryptography.RandomNumberGenerator]::Fill($buffer)
    return [Convert]::ToBase64String($buffer).TrimEnd('=').Replace('+', 'A').Replace('/', 'B')
}

$envPath = Join-Path $PSScriptRoot '.env'
if (Test-Path $envPath) {
    Write-Output 'ENV_EXISTS_NO_CHANGE'
    exit 0
}

$tokenBytes = New-Object byte[] 48
[System.Security.Cryptography.RandomNumberGenerator]::Fill($tokenBytes)
$nacosToken = [Convert]::ToBase64String($tokenBytes)

@"
MYSQL_ROOT_PASSWORD=$(New-Secret 24)
NACOS_DB_PASSWORD=$(New-Secret 24)
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
