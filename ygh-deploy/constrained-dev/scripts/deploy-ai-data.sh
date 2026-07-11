#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."
test -f .env || { echo '.env missing' >&2; exit 1; }

available_kib="$(awk '/MemAvailable:/ { print $2 }' /proc/meminfo)"
if (( available_kib < 700000 )); then
  echo "AI_DATA_START_BLOCKED mem_available_kib=${available_kib}" >&2
  exit 1
fi

compose=(docker compose --env-file .env -f vm-compose.yml --profile ai-data)
"${compose[@]}" config >/dev/null
"${compose[@]}" pull pgvector
"${compose[@]}" up -d pgvector

for attempt in $(seq 1 30); do
  if "${compose[@]}" exec -T pgvector pg_isready -U ygh_vector -d ygh_vector >/dev/null 2>&1; then
    "${compose[@]}" exec -T pgvector \
      psql -U ygh_vector -d ygh_vector -tAc \
      "SELECT extversion FROM pg_extension WHERE extname = 'vector';"
    echo AI_DATA_HEALTH_OK
    exit 0
  fi
  sleep 2
done

"${compose[@]}" logs --tail 120 pgvector >&2
echo AI_DATA_READINESS_TIMEOUT >&2
exit 1
