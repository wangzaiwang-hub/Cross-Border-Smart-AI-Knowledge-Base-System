$ErrorActionPreference = "Stop"
$services = docker compose --env-file .env config --services
$failed = @()
foreach ($service in $services) {
    $id = docker compose --env-file .env ps -q $service
    if (-not $id) { $failed += "${service}:not-running"; continue }
    $status = docker inspect --format '{{if .State.Health}}{{.State.Health.Status}}{{else}}{{.State.Status}}{{end}}' $id
    if ($status -notin @('healthy', 'running')) { $failed += "${service}:$status" }
}
if ($failed.Count -gt 0) { throw "Unhealthy services: $($failed -join ', ')" }
Write-Host "All $($services.Count) services are running or healthy."
