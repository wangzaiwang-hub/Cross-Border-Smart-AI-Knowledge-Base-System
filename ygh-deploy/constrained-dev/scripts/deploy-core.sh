#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."
test -f .env || { echo '.env missing' >&2; exit 1; }
docker compose --env-file .env -f vm-compose.yml --profile core config >/dev/null
docker compose --parallel 1 --env-file .env -f vm-compose.yml --profile core pull
docker compose --env-file .env -f vm-compose.yml --profile core up -d
"$(dirname "$0")/health-check.sh"
"$(dirname "$0")/provision-auth-db.sh"
"$(dirname "$0")/verify-auth-db.sh"
"$(dirname "$0")/initialize-nacos-admin.sh"
