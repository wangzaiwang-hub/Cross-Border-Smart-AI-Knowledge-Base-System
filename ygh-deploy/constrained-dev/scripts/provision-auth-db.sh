#!/bin/sh
set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
COMPOSE_DIR=$(dirname "$SCRIPT_DIR")

cd "$COMPOSE_DIR"
set -a
normalized_env=$(mktemp)
trap 'rm -f "$normalized_env"' EXIT HUP INT TERM
tr -d '\r' < .env > "$normalized_env"
# shellcheck disable=SC1090
. "$normalized_env"
set +a

docker compose --env-file .env -f vm-compose.yml --profile core exec -T \
  -e AUTH_DB_APP_PASSWORD \
  -e AUTH_DB_MIGRATION_PASSWORD \
  mysql \
  sh /docker-entrypoint-initdb.d/02-auth-database.sh

echo AUTH_DB_PROVISIONED
