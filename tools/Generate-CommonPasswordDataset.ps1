param(
    [Parameter(Mandatory = $true)] [string] $SourcePath,
    [string] $OutputPath = "ygh-platform/ygh-auth-service/src/main/resources/security/common-passwords-sha256.bin"
)

$ErrorActionPreference = "Stop"
$ExpectedSourceSha256 = "1472aafa2561df5e3293aee252aee3ca660c12b399a283cf808bb01b39be388b"
$ExpectedOutputSha256 = "d27cc6628a51c24255521284ce4c7d50bca1365a8224a42d0b92420df78c8ba6"
$ExpectedEntries = 96518

$actualSourceSha256 = (Get-FileHash -LiteralPath $SourcePath -Algorithm SHA256).Hash.ToLowerInvariant()
if ($actualSourceSha256 -ne $ExpectedSourceSha256) {
    throw "Upstream common-password source checksum mismatch."
}

$sha256 = [System.Security.Cryptography.SHA256]::Create()
$digests = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::Ordinal)
try {
    foreach ($line in [System.IO.File]::ReadLines((Resolve-Path -LiteralPath $SourcePath))) {
        foreach ($character in $line.ToCharArray()) {
            if ([int] $character -gt 127) { throw "The upstream dataset contains a non-ASCII line." }
        }
        $normalized = $line.ToLowerInvariant()
        $bytes = [System.Text.Encoding]::UTF8.GetBytes($normalized)
        try {
            [void] $digests.Add([Convert]::ToHexString($sha256.ComputeHash($bytes)))
        } finally {
            [Array]::Clear($bytes, 0, $bytes.Length)
        }
    }
} finally {
    $sha256.Dispose()
}

if ($digests.Count -ne $ExpectedEntries) { throw "Unexpected deduplicated entry count: $($digests.Count)." }
$ordered = [string[]] $digests
[Array]::Sort($ordered, [System.StringComparer]::Ordinal)
[System.IO.Directory]::CreateDirectory((Split-Path -Parent $OutputPath)) | Out-Null
$stream = [System.IO.File]::Open($OutputPath, [System.IO.FileMode]::Create)
try {
    foreach ($hex in $ordered) {
        $bytes = [Convert]::FromHexString($hex)
        try { $stream.Write($bytes, 0, $bytes.Length) }
        finally { [Array]::Clear($bytes, 0, $bytes.Length) }
    }
} finally {
    $stream.Dispose()
}

$actualOutputSha256 = (Get-FileHash -LiteralPath $OutputPath -Algorithm SHA256).Hash.ToLowerInvariant()
if ($actualOutputSha256 -ne $ExpectedOutputSha256) {
    throw "Generated common-password dataset checksum mismatch."
}
Write-Output "Generated $ExpectedEntries digests; SHA-256=$actualOutputSha256"
