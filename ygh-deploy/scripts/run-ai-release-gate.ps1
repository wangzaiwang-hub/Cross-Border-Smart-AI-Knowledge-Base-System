[CmdletBinding()]
param(
    [string]$GatewayUrl = "http://localhost:8080",
    [string]$ReportPath = "test-results/ai/ai-release-gate.json",
    [ValidateRange(0.5, 1.0)][double]$MinimumOverallAccuracy = 0.90,
    [ValidateRange(0.5, 1.0)][double]$MinimumRefusalAccuracy = 1.0
)

$ErrorActionPreference = "Stop"
$token = $env:YGH_ACCESS_TOKEN
if ([string]::IsNullOrWhiteSpace($token)) {
    throw "YGH_ACCESS_TOKEN is required and must belong to an administrator with AI evaluation permissions"
}
$headers = @{ Authorization = "Bearer $token" }
$base = $GatewayUrl.TrimEnd('/')

$caseResponse = Invoke-RestMethod -Headers $headers -Uri "$base/api/v1/admin/ai/evaluation-cases"
$cases = @($caseResponse.data | Where-Object enabled)
if ($cases.Count -lt 2) { throw "At least two reviewed and enabled evaluation cases are required" }
$answerCases = @($cases | Where-Object { -not $_.expectedRefusal })
$refusalCases = @($cases | Where-Object expectedRefusal)
if ($answerCases.Count -eq 0 -or $refusalCases.Count -eq 0) {
    throw "The enabled evaluation set must contain both evidence-answer and expected-refusal cases"
}

$runResponse = Invoke-RestMethod -Method Post -Headers $headers -Uri "$base/api/v1/admin/ai/evaluations/run"
$runs = @($runResponse.data)
if ($runs.Count -ne $cases.Count) {
    throw "Evaluation run count $($runs.Count) does not match enabled case count $($cases.Count)"
}
$caseById = @{}; foreach ($case in $cases) { $caseById[[string]$case.id] = $case }
$refusalRuns = @($runs | Where-Object { $caseById[[string]$_.caseId].expectedRefusal })
$answerRuns = @($runs | Where-Object { -not $caseById[[string]$_.caseId].expectedRefusal })
$overallAccuracy = @($runs | Where-Object passed).Count / $runs.Count
$refusalAccuracy = @($refusalRuns | Where-Object passed).Count / $refusalRuns.Count
$answerWithoutCitation = @($answerRuns | Where-Object { $_.passed -and $_.citationCount -lt 1 })
if ($answerWithoutCitation.Count -gt 0) { throw "A passed answer evaluation has no citation" }

$report = [ordered]@{
    generatedAt = [DateTimeOffset]::UtcNow.ToString("O")
    gateway = $base
    enabledCases = $cases.Count
    answerCases = $answerCases.Count
    refusalCases = $refusalCases.Count
    passed = @($runs | Where-Object passed).Count
    overallAccuracy = [Math]::Round($overallAccuracy, 4)
    refusalAccuracy = [Math]::Round($refusalAccuracy, 4)
    minimumOverallAccuracy = $MinimumOverallAccuracy
    minimumRefusalAccuracy = $MinimumRefusalAccuracy
    failures = @($runs | Where-Object { -not $_.passed } | ForEach-Object {
        [ordered]@{ caseId = $_.caseId; reason = $_.failureReason; score = $_.score; citationCount = $_.citationCount }
    })
}
$output = [IO.Path]::GetFullPath($ReportPath)
New-Item -ItemType Directory -Force -Path (Split-Path -Parent $output) | Out-Null
$report | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $output -Encoding utf8NoBOM
if ($overallAccuracy -lt $MinimumOverallAccuracy) {
    throw "AI overall accuracy $overallAccuracy is below $MinimumOverallAccuracy; inspect $output"
}
if ($refusalAccuracy -lt $MinimumRefusalAccuracy) {
    throw "AI refusal accuracy $refusalAccuracy is below $MinimumRefusalAccuracy; inspect $output"
}
Write-Output "AI_RELEASE_GATE_OK cases=$($runs.Count) overall=$overallAccuracy refusal=$refusalAccuracy report=$output"
