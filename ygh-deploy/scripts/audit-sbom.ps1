param(
    [string]$BomPath = "target/bom.json"
)

$ErrorActionPreference = "Stop"
if (-not (Test-Path -LiteralPath $BomPath -PathType Leaf)) {
    throw "CycloneDX BOM not found: $BomPath"
}

$allowedPattern = '^(Apache-2\.0|Apache License v2|MIT|MIT-0|BSD-2-Clause|BSD-3-Clause|BSD-4-Clause|BSD licence|BSD 3-clause License w/nuclear disclaimer|0BSD|ISC|EPL-2\.0|CDDL-1\.1|CDDL, v1\.0|Unicode-3\.0|Unicode/ICU License|CC0-1\.0|Public-Domain|Public Domain|Bouncy Castle Licence)$'
$deniedPattern = '(?i)(AGPL|Affero|Server Side Public License|SSPL)'
$bom = Get-Content -Raw -LiteralPath $BomPath | ConvertFrom-Json
$missing = [System.Collections.Generic.List[string]]::new()
$denied = [System.Collections.Generic.List[string]]::new()
$manual = [System.Collections.Generic.List[string]]::new()

foreach ($component in @($bom.components)) {
    $coordinates = "$($component.group):$($component.name):$($component.version)"
    if ($component.group -eq "com.yuegang.zhihui") { continue }
    $licenses = @($component.licenses | ForEach-Object {
        if ($_.license.id) { $_.license.id }
        elseif ($_.license.name) { $_.license.name }
        elseif ($_.expression) { $_.expression }
    } | Where-Object { $_ })
    if ($licenses.Count -eq 0) {
        $missing.Add($coordinates)
        continue
    }
    foreach ($license in $licenses) {
        if ($license -match $deniedPattern) { $denied.Add("$coordinates [$license]") }
        elseif ($license -notmatch $allowedPattern) { $manual.Add("$coordinates [$license]") }
    }
}

if ($manual.Count -gt 0) {
    Write-Warning "Manual license review required:`n$($manual -join "`n")"
}
if ($missing.Count -gt 0) {
    Write-Warning "Components without license metadata require manual review:`n$($missing -join "`n")"
}
if ($denied.Count -gt 0) {
    Write-Error "Forbidden licenses detected:`n$($denied -join "`n")"
    exit 1
}
Write-Output "SBOM_LICENSE_AUDIT_OK components=$(@($bom.components).Count) manualReview=$($manual.Count + $missing.Count)"
