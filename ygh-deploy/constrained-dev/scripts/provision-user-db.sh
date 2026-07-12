#!/bin/sh
set -eu
SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
COMPOSE_DIR=$(dirname "$SCRIPT_DIR")
cd "$COMPOSE_DIR"
normalized_env=$(mktemp)
trap 'rm -f "$normalized_env"' EXIT HUP INT TERM
tr -d '\r' < .env > "$normalized_env"
set -a
. "$normalized_env"
set +a
docker compose --env-file .env -f vm-compose.yml --profile core exec -T \
  -e MYSQL_ROOT_PASSWORD -e USER_DB_APP_PASSWORD -e USER_DB_MIGRATION_PASSWORD mysql \
  sh -s < mysql/init/03-user-database.sh
echo USER_DB_PROVISIONED
