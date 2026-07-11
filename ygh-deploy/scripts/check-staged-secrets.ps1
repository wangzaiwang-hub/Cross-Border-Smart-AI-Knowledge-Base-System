param(
    [switch]$ScanWorkingTree
)

$ErrorActionPreference = 'Stop'

if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    throw 'git command is required'
}

$repositoryRoot = (& git rev-parse --show-toplevel 2>$null)
if ($LASTEXITCODE -ne 0 -or -not $repositoryRoot) {
    throw 'Current directory is not inside a Git repository'
}

$forbiddenPaths = @(
    '(^|/)\.env($|\.)',
    '(^|/)secrets/(?!\.gitkeep$)',
    '\.(key|pem|p12|pfx|jks)$',
    '^[^/]+\.(doc|docx)$'
)

$secretPatterns = @(
    '(?i)-----BEGIN (RSA |EC |OPENSSH )?PRIVATE KEY-----',
    '(?i)(api[_-]?key|access[_-]?token|secret[_-]?key|password|passwd)\s*(?:=|:\s+)\s*["'']?(?!\$\{)[A-Za-z0-9_./=@-]{8,}',
    '\bgh[opsu]_[A-Za-z0-9]{30,}\b',
    '\bsk-[A-Za-z0-9]{20,}\b'
)

if ($ScanWorkingTree) {
    $files = @(& git -c core.quotepath=false ls-files --cached --others --exclude-standard)
} else {
    $files = @(& git -c core.quotepath=false diff --cached --name-only --diff-filter=ACMR)
}

$violations = [System.Collections.Generic.List[string]]::new()
foreach ($file in $files) {
    if ([string]::IsNullOrWhiteSpace($file)) {
        continue
    }

    $normalized = $file.Replace('\', '/')
    foreach ($pattern in $forbiddenPaths) {
        if ($normalized -match $pattern -and $normalized -notmatch '(^|/)\.env\.example$') {
            $violations.Add("forbidden path: $normalized")
        }
    }

    $content = if ($ScanWorkingTree) {
        $absolutePath = Join-Path $repositoryRoot $file
        if (Test-Path -LiteralPath $absolutePath -PathType Leaf) {
            Get-Content -Raw -LiteralPath $absolutePath -ErrorAction SilentlyContinue
        }
    } else {
        & git show ":$file" 2>$null
    }

    if ($null -eq $content) {
        continue
    }

    $text = [string]::Join("`n", $content)
    $text = $text.Replace('change-me', '${PLACEHOLDER}')
    $text = $text.Replace('base64-at-least-32-bytes', '${PLACEHOLDER}')
    $text = $text.Replace('replace-me', '${PLACEHOLDER}')
    foreach ($pattern in $secretPatterns) {
        if ($text -match $pattern) {
            $violations.Add("possible secret in: $normalized")
        }
    }
}

if ($violations.Count -gt 0) {
    $violations | Sort-Object -Unique | ForEach-Object { Write-Error $_ }
    exit 1
}

Write-Output "SECRET_SCAN_OK files=$($files.Count) mode=$(if ($ScanWorkingTree) { 'working-tree' } else { 'staged' })"
