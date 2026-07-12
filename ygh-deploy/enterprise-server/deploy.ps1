param(
    [Parameter(Mandatory = $true)][string]$Version,
    [string]$Registry = "ghcr.io/wangzaiwang-hub",
    [switch]$SkipPull
)
$ErrorActionPreference = "Stop"
$env:YGH_VERSION = $Version
$env:YGH_REGISTRY = $Registry
docker compose --env-file .env config --quiet
if (-not $SkipPull) { docker compose --env-file .env pull }
docker compose --env-file .env up -d --remove-orphans
docker compose --env-file .env ps
