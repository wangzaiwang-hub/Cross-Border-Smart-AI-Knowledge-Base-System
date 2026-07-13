[CmdletBinding()]
param(
    [Parameter(Mandatory)][ValidatePattern('^https?://')][string]$TargetUrl,
    [Parameter(Mandatory)][string]$OpenApiFile,
    [string]$ReportDirectory = "test-results/security",
    [ValidateSet("WARN", "FAIL")][string]$AlertLevel = "FAIL"
)

$ErrorActionPreference = "Stop"
$spec = (Resolve-Path -LiteralPath $OpenApiFile).Path
$reports = [System.IO.Path]::GetFullPath($ReportDirectory)
New-Item -ItemType Directory -Force -Path $reports | Out-Null
$scanSpec = Join-Path $reports "scan-openapi.json"
$document = Get-Content -Raw -LiteralPath $spec | ConvertFrom-Json
$document | Add-Member -Force -NotePropertyName servers -NotePropertyValue @(@{ url = $TargetUrl.TrimEnd('/') })
$document | ConvertTo-Json -Depth 100 -Compress | Set-Content -LiteralPath $scanSpec -Encoding utf8NoBOM
$reportMount = $reports.Replace('\', '/')

$arguments = @(
    "run", "--rm",
    "--add-host", "host.docker.internal:host-gateway",
    "-v", "${reportMount}:/zap/wrk:rw",
    "ghcr.io/zaproxy/zaproxy:stable",
    "zap-api-scan.py",
    "-t", "/zap/wrk/scan-openapi.json",
    "-f", "openapi",
    "-r", "zap-api-report.html",
    "-J", "zap-api-report.json"
)
if ($AlertLevel -eq "WARN") { $arguments += "-I" }

& docker @arguments
if ($LASTEXITCODE -ne 0) {
    throw "ZAP API scan failed with exit code $LASTEXITCODE; inspect $reports"
}
Write-Output "API_SECURITY_SCAN_OK target=$TargetUrl report=$reports"
