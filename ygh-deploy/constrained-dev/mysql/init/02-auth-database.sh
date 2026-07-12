#!/bin/sh
set -eu

: "${MYSQL_ROOT_PASSWORD:?MYSQL_ROOT_PASSWORD is required}"
: "${AUTH_DB_APP_PASSWORD:?AUTH_DB_APP_PASSWORD is required}"
: "${AUTH_DB_MIGRATION_PASSWORD:?AUTH_DB_MIGRATION_PASSWORD is required}"

validate_secret() {
  value=$1
  name=$2
  case "$value" in
    *[!A-Za-z0-9]*|'')
      echo "$name must contain only ASCII letters and digits" >&2
      exit 1
      ;;
  esac
  if [ "${#value}" -lt 24 ] || [ "${#value}" -gt 128 ]; then
    echo "$name length must be between 24 and 128 characters" >&2
    exit 1
  fi
}

validate_secret "$AUTH_DB_APP_PASSWORD" AUTH_DB_APP_PASSWORD
validate_secret "$AUTH_DB_MIGRATION_PASSWORD" AUTH_DB_MIGRATION_PASSWORD

MYSQL_PWD="$MYSQL_ROOT_PASSWORD" mysql --protocol=socket -uroot <<-EOSQL
CREATE DATABASE IF NOT EXISTS auth_db CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci;
CREATE USER IF NOT EXISTS 'ygh_auth_app'@'%' IDENTIFIED BY '${AUTH_DB_APP_PASSWORD}';
ALTER USER 'ygh_auth_app'@'%' IDENTIFIED BY '${AUTH_DB_APP_PASSWORD}';
CREATE USER IF NOT EXISTS 'ygh_auth_migration'@'%' IDENTIFIED BY '${AUTH_DB_MIGRATION_PASSWORD}';
ALTER USER 'ygh_auth_migration'@'%' IDENTIFIED BY '${AUTH_DB_MIGRATION_PASSWORD}';
REVOKE ALL PRIVILEGES, GRANT OPTION FROM 'ygh_auth_app'@'%';
REVOKE ALL PRIVILEGES, GRANT OPTION FROM 'ygh_auth_migration'@'%';
GRANT SELECT, INSERT, UPDATE, DELETE, CREATE, ALTER, INDEX, REFERENCES, DROP ON auth_db.* TO 'ygh_auth_migration'@'%';
FLUSH PRIVILEGES;
EOSQL

table_count=$(MYSQL_PWD="$MYSQL_ROOT_PASSWORD" mysql --protocol=socket -uroot -Nse \
  "SELECT COUNT(*) FROM information_schema.TABLES
   WHERE TABLE_SCHEMA = 'auth_db'
     AND TABLE_NAME IN ('auth_account','auth_credential','auth_refresh_token','auth_login_attempt','auth_account_admin_audit')")

if [ "$table_count" -eq 5 ]; then
  MYSQL_PWD="$MYSQL_ROOT_PASSWORD" mysql --protocol=socket -uroot <<-EOSQL
GRANT SELECT, INSERT, UPDATE, DELETE ON auth_db.auth_account TO 'ygh_auth_app'@'%';
GRANT SELECT, INSERT, UPDATE, DELETE ON auth_db.auth_credential TO 'ygh_auth_app'@'%';
GRANT SELECT, INSERT, UPDATE, DELETE ON auth_db.auth_refresh_token TO 'ygh_auth_app'@'%';
GRANT SELECT, INSERT, UPDATE, DELETE ON auth_db.auth_login_attempt TO 'ygh_auth_app'@'%';
GRANT SELECT, INSERT, UPDATE, DELETE ON auth_db.auth_account_admin_audit TO 'ygh_auth_app'@'%';
FLUSH PRIVILEGES;
EOSQL
fi
