$ErrorActionPreference = 'Stop'
& (Join-Path $PSScriptRoot 'local-profile.ps1') -Mode status
