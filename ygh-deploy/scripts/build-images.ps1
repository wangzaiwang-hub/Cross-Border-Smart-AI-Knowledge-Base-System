param(
    [Parameter(Mandatory=$true)][string]$Version,
    [string]$Registry="ghcr.io/wangzaiwang-hub",
    [switch]$Push
)
$ErrorActionPreference="Stop"
$sha=(git rev-parse HEAD).Trim()
$built=(Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
$modules=[ordered]@{
  "ygh-gateway"="ygh-platform/ygh-gateway"; "ygh-auth-service"="ygh-platform/ygh-auth-service";
  "ygh-user-service"="ygh-applications/ygh-user/ygh-user-service"; "ygh-system-service"="ygh-applications/ygh-system/ygh-system-service";
  "ygh-product-service"="ygh-applications/ygh-product/ygh-product-service"; "ygh-inventory-service"="ygh-applications/ygh-inventory/ygh-inventory-service";
  "ygh-order-service"="ygh-applications/ygh-order/ygh-order-service"; "ygh-wallet-service"="ygh-applications/ygh-wallet/ygh-wallet-service";
  "ygh-knowledge-service"="ygh-applications/ygh-knowledge/ygh-knowledge-service"; "ygh-search-service"="ygh-applications/ygh-search/ygh-search-service";
  "ygh-ai-service"="ygh-applications/ygh-ai/ygh-ai-service"; "ygh-training-service"="ygh-applications/ygh-training/ygh-training-service";
  "ygh-notification-service"="ygh-applications/ygh-notification/ygh-notification-service"; "ygh-admin-service"="ygh-applications/ygh-admin/ygh-admin-service"
}
foreach($entry in $modules.GetEnumerator()){
  $image="$Registry/$($entry.Key):$Version"
  docker build --build-arg APP_VERSION=$Version --build-arg GIT_SHA=$sha --build-arg BUILD_TIME=$built --tag $image $entry.Value
  if($LASTEXITCODE-ne 0){throw "Image build failed: $($entry.Key)"}
  if($Push){docker push $image;if($LASTEXITCODE-ne 0){throw "Image push failed: $($entry.Key)"}}
}
$webModules=[ordered]@{
  "ygh-web-mall"="ygh-web/apps/ygh-web-mall/Dockerfile";
  "ygh-web-admin"="ygh-web/apps/ygh-web-admin/Dockerfile"
}
foreach($entry in $webModules.GetEnumerator()){
  $image="$Registry/$($entry.Key):$Version"
  docker build --file $entry.Value --build-arg APP_VERSION=$Version --build-arg GIT_SHA=$sha --build-arg BUILD_TIME=$built --tag $image ygh-web
  if($LASTEXITCODE-ne 0){throw "Image build failed: $($entry.Key)"}
  if($Push){docker push $image;if($LASTEXITCODE-ne 0){throw "Image push failed: $($entry.Key)"}}
}
Write-Host "IMAGE_BUILD_OK version=$Version gitSha=$sha count=$($modules.Count+$webModules.Count)"
