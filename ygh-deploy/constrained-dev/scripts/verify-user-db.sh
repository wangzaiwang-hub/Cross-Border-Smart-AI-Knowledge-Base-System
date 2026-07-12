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
compose_exec() { docker compose --env-file .env -f vm-compose.yml --profile core exec -T "$@"; }
MYSQL_PWD=$USER_DB_MIGRATION_PASSWORD; export MYSQL_PWD
table_count=$(compose_exec -e MYSQL_PWD mysql mysql -h127.0.0.1 -uygh_user_migration -Duser_db -Nse \
  "SELECT COUNT(*) FROM information_schema.TABLES WHERE TABLE_SCHEMA=DATABASE()")
if [ "$table_count" -eq 0 ]; then echo USER_DB_READY_FOR_MIGRATION; exit 0; fi
[ "$table_count" -eq 7 ] || { echo "USER_DB_TABLE_COUNT_UNEXPECTED:$table_count" >&2; exit 1; }
version=$(compose_exec -e MYSQL_PWD mysql mysql -h127.0.0.1 -uygh_user_migration -Duser_db -Nse \
  "SELECT version FROM flyway_schema_history WHERE success=1 ORDER BY installed_rank DESC LIMIT 1")
[ "$version" = "1" ] || { echo "USER_DB_SCHEMA_VERSION_UNEXPECTED:$version" >&2; exit 1; }
MYSQL_PWD=$USER_DB_APP_PASSWORD; export MYSQL_PWD
compose_exec -e MYSQL_PWD mysql mysql -h127.0.0.1 -uygh_user_app -Duser_db -Nse "SELECT 1" >/dev/null
if compose_exec -e MYSQL_PWD mysql mysql -h127.0.0.1 -uygh_user_app -Duser_db -e \
  "CREATE TABLE forbidden_user_ddl(id BIGINT)" >/dev/null 2>&1; then
  echo USER_APP_DDL_UNEXPECTEDLY_ALLOWED >&2; exit 1
fi
echo USER_DB_PRIVILEGES_VERIFIED
