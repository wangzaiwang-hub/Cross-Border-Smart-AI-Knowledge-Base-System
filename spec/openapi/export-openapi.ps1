param([string]$GatewayUrl="http://localhost:8080",[string]$OutputDirectory=$PSScriptRoot)
$ErrorActionPreference="Stop"
$services=[ordered]@{gateway=8080;auth=8081;user=8082;system=8083;product=8084;inventory=8085;order=8086;wallet=8087;knowledge=8088;search=8089;ai=8090;training=8091;notification=8092;admin=8093}
New-Item -ItemType Directory -Force -Path $OutputDirectory|Out-Null
foreach($entry in $services.GetEnumerator()){$url=if($entry.Key -eq 'gateway'){"$GatewayUrl/v3/api-docs"}else{"http://localhost:$($entry.Value)/v3/api-docs"};Invoke-WebRequest -UseBasicParsing -Uri $url -OutFile (Join-Path $OutputDirectory "$($entry.Key)-service-v1.json")}
