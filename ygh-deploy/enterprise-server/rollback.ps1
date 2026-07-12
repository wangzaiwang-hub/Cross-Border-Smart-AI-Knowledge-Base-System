param([Parameter(Mandatory = $true)][string]$Version)
$ErrorActionPreference = "Stop"
$env:YGH_VERSION = $Version
docker compose --env-file .env config --quiet
docker compose --env-file .env pull
docker compose --env-file .env up -d --remove-orphans
docker compose --env-file .env ps
