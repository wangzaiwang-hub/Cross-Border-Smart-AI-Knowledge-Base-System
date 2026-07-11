#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

compose=(docker compose --env-file .env -f vm-compose.yml --profile core)
"${compose[@]}" ps

# 首次启动时 MySQL 初始化和 Nacos 3 的三个应用上下文启动可能超过 30 秒。
# 在容器内部探测，避免受宿主机端口仅绑定 192.168.154.10 的影响。
nacos_ready=false
for attempt in $(seq 1 60); do
  if "${compose[@]}" exec -T nacos \
    curl -fsS http://127.0.0.1:8848/nacos/v3/admin/core/state/readiness >/dev/null 2>&1; then
    nacos_ready=true
    break
  fi
  if (( attempt % 10 == 0 )); then
    echo "WAITING_FOR_NACOS attempt=${attempt}/60"
  fi
  sleep 3
done

if [[ "$nacos_ready" != true ]]; then
  "${compose[@]}" ps >&2
  "${compose[@]}" logs --tail 120 nacos >&2
  echo NACOS_READINESS_TIMEOUT >&2
  exit 1
fi

docker compose --env-file .env -f vm-compose.yml --profile core exec -T mysql \
  sh -c 'MYSQL_PWD="$MYSQL_ROOT_PASSWORD" mysql -uroot -e "SELECT 1"' >/dev/null
docker compose --env-file .env -f vm-compose.yml --profile core exec -T redis \
  sh -c 'REDISCLI_AUTH="$REDIS_PASSWORD" redis-cli ping' | grep -q PONG
"${compose[@]}" exec -T nacos \
  curl -fsS http://127.0.0.1:8080/v3/console/health/readiness >/dev/null
free -h
df -h /
docker stats --no-stream
echo CORE_HEALTH_OK
