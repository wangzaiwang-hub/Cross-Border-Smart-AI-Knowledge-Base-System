#!/bin/sh
set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
COMPOSE_DIR=$(dirname "$SCRIPT_DIR")
cd "$COMPOSE_DIR"

normalized_env=$(mktemp)
trap 'rm -f "$normalized_env"' EXIT HUP INT TERM
tr -d '\r' < .env > "$normalized_env"
set -a
# shellcheck disable=SC1090
. "$normalized_env"
set +a

compose_exec() {
  docker compose --env-file .env -f vm-compose.yml --profile core exec -T "$@"
}

MYSQL_PWD=$AUTH_DB_MIGRATION_PASSWORD
export MYSQL_PWD
table_count=$(compose_exec -e MYSQL_PWD mysql \
  mysql -h127.0.0.1 -uygh_auth_migration -Dauth_db -Nse \
  "SELECT COUNT(*) FROM information_schema.TABLES WHERE TABLE_SCHEMA = DATABASE()")
if [ "$table_count" -eq 0 ]; then
  echo AUTH_DB_READY_FOR_MIGRATION
  exit 0
fi

MYSQL_PWD=$AUTH_DB_APP_PASSWORD
export MYSQL_PWD
compose_exec -e MYSQL_PWD mysql \
  mysql -h127.0.0.1 -uygh_auth_app -Dauth_db -Nse "SELECT 1" >/dev/null
if [ "$table_count" -ne 4 ]; then
  echo "AUTH_DB_TABLE_COUNT_UNEXPECTED:$table_count" >&2
  exit 1
fi
MYSQL_PWD=$AUTH_DB_MIGRATION_PASSWORD
export MYSQL_PWD
schema_version=$(compose_exec -e MYSQL_PWD mysql \
  mysql -h127.0.0.1 -uygh_auth_migration -Dauth_db -Nse \
  "SELECT version FROM flyway_schema_history WHERE success = 1 ORDER BY installed_rank DESC LIMIT 1")
if [ "$schema_version" != "1" ]; then
  echo "AUTH_DB_SCHEMA_VERSION_UNEXPECTED:$schema_version" >&2
  exit 1
fi

MYSQL_PWD=$AUTH_DB_APP_PASSWORD
export MYSQL_PWD
if compose_exec -e MYSQL_PWD mysql \
  mysql -h127.0.0.1 -uygh_auth_app -Dauth_db \
  -e "DELETE FROM flyway_schema_history WHERE 1 = 0" >/dev/null 2>&1; then
  echo AUTH_APP_FLYWAY_HISTORY_WRITE_ALLOWED >&2
  exit 1
fi

if compose_exec -e MYSQL_PWD mysql \
  mysql -h127.0.0.1 -uygh_auth_app -Dauth_db \
  -e "CREATE TABLE forbidden_app_ddl (id BIGINT)" >/dev/null 2>&1; then
  MYSQL_PWD=$AUTH_DB_MIGRATION_PASSWORD
  export MYSQL_PWD
  compose_exec -e MYSQL_PWD mysql \
    mysql -h127.0.0.1 -uygh_auth_migration -Dauth_db \
    -e "DROP TABLE forbidden_app_ddl" >/dev/null 2>&1 || true
  echo AUTH_APP_DDL_UNEXPECTEDLY_ALLOWED >&2
  exit 1
fi

MYSQL_PWD=$AUTH_DB_MIGRATION_PASSWORD
export MYSQL_PWD
compose_exec -e MYSQL_PWD mysql \
  mysql -h127.0.0.1 -uygh_auth_migration -Dauth_db \
  -e "CREATE TABLE privilege_probe (id BIGINT); DROP TABLE privilege_probe" >/dev/null

app_grants=$(compose_exec mysql sh -c \
  'MYSQL_PWD="$MYSQL_ROOT_PASSWORD" mysql -uroot -Nse "SHOW GRANTS FOR '\''ygh_auth_app'\''@'\''%'\''"')
migration_grants=$(compose_exec mysql sh -c \
  'MYSQL_PWD="$MYSQL_ROOT_PASSWORD" mysql -uroot -Nse "SHOW GRANTS FOR '\''ygh_auth_migration'\''@'\''%'\''"')

app_usage='GRANT USAGE ON *.* TO `ygh_auth_app`@`%`'
app_account='GRANT SELECT, INSERT, UPDATE, DELETE ON `auth_db`.`auth_account` TO `ygh_auth_app`@`%`'
app_credential='GRANT SELECT, INSERT, UPDATE, DELETE ON `auth_db`.`auth_credential` TO `ygh_auth_app`@`%`'
app_refresh='GRANT SELECT, INSERT, UPDATE, DELETE ON `auth_db`.`auth_refresh_token` TO `ygh_auth_app`@`%`'
app_attempt='GRANT SELECT, INSERT, UPDATE, DELETE ON `auth_db`.`auth_login_attempt` TO `ygh_auth_app`@`%`'
if [ "$(printf '%s\n' "$app_grants" | sed '/^$/d' | wc -l)" -ne 5 ] ||
   ! printf '%s\n' "$app_grants" | grep -Fqx "$app_usage" ||
   ! printf '%s\n' "$app_grants" | grep -Fqx "$app_account" ||
   ! printf '%s\n' "$app_grants" | grep -Fqx "$app_credential" ||
   ! printf '%s\n' "$app_grants" | grep -Fqx "$app_refresh" ||
   ! printf '%s\n' "$app_grants" | grep -Fqx "$app_attempt"; then
  echo AUTH_APP_GRANT_DRIFT >&2
  exit 1
fi
migration_usage='GRANT USAGE ON *.* TO `ygh_auth_migration`@`%`'
migration_database='GRANT SELECT, INSERT, UPDATE, DELETE, CREATE, DROP, REFERENCES, INDEX, ALTER ON `auth_db`.* TO `ygh_auth_migration`@`%`'
if [ "$(printf '%s\n' "$migration_grants" | sed '/^$/d' | wc -l)" -ne 2 ] ||
   ! printf '%s\n' "$migration_grants" | grep -Fqx "$migration_usage" ||
   ! printf '%s\n' "$migration_grants" | grep -Fqx "$migration_database"; then
  echo AUTH_MIGRATION_GRANT_DRIFT >&2
  exit 1
fi

echo AUTH_DB_PRIVILEGES_VERIFIED
