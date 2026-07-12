param([ValidateSet('platform','mall','ai-apps','training')][string]$Profile,[ValidateSet('up','down','status')][string]$Action='up')
$ErrorActionPreference='Stop'
$root=Split-Path -Parent $PSScriptRoot
$compose=Join-Path $root 'apps-compose.yml'
$envFile=Join-Path $root '.env'
if(-not(Test-Path $envFile)){throw '.env missing; run generate-env.ps1 first'}
if($Action -eq 'up') { & "$PSScriptRoot\..\..\..\mvnw.cmd" package -DskipTests; if($LASTEXITCODE){exit $LASTEXITCODE}; docker compose --env-file $envFile -f $compose --profile $Profile up -d --build }
elseif($Action -eq 'down'){docker compose --env-file $envFile -f $compose --profile $Profile down}
else{docker compose --env-file $envFile -f $compose --profile $Profile ps}
exit $LASTEXITCODE
