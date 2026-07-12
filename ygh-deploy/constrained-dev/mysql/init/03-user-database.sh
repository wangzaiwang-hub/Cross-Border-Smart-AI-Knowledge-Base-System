#!/bin/sh
set -eu
: "${MYSQL_ROOT_PASSWORD:?MYSQL_ROOT_PASSWORD is required}"
: "${USER_DB_APP_PASSWORD:?USER_DB_APP_PASSWORD is required}"
: "${USER_DB_MIGRATION_PASSWORD:?USER_DB_MIGRATION_PASSWORD is required}"
validate_secret() {
  value=$1 name=$2
  case "$value" in *[!A-Za-z0-9]*|'') echo "$name must contain only ASCII letters and digits" >&2; exit 1;; esac
  [ "${#value}" -ge 24 ] && [ "${#value}" -le 128 ] || { echo "$name length is invalid" >&2; exit 1; }
}
validate_secret "$USER_DB_APP_PASSWORD" USER_DB_APP_PASSWORD
validate_secret "$USER_DB_MIGRATION_PASSWORD" USER_DB_MIGRATION_PASSWORD
MYSQL_PWD="$MYSQL_ROOT_PASSWORD" mysql --protocol=socket -uroot <<-EOSQL
CREATE DATABASE IF NOT EXISTS user_db CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci;
CREATE USER IF NOT EXISTS 'ygh_user_app'@'%' IDENTIFIED BY '${USER_DB_APP_PASSWORD}';
ALTER USER 'ygh_user_app'@'%' IDENTIFIED BY '${USER_DB_APP_PASSWORD}';
CREATE USER IF NOT EXISTS 'ygh_user_migration'@'%' IDENTIFIED BY '${USER_DB_MIGRATION_PASSWORD}';
ALTER USER 'ygh_user_migration'@'%' IDENTIFIED BY '${USER_DB_MIGRATION_PASSWORD}';
REVOKE ALL PRIVILEGES, GRANT OPTION FROM 'ygh_user_app'@'%';
REVOKE ALL PRIVILEGES, GRANT OPTION FROM 'ygh_user_migration'@'%';
GRANT SELECT, INSERT, UPDATE, DELETE, CREATE, DROP, REFERENCES, INDEX, ALTER ON user_db.* TO 'ygh_user_migration'@'%';
FLUSH PRIVILEGES;
EOSQL
table_count=$(MYSQL_PWD="$MYSQL_ROOT_PASSWORD" mysql --protocol=socket -uroot -Nse \
  "SELECT COUNT(*) FROM information_schema.TABLES WHERE TABLE_SCHEMA='user_db' AND TABLE_NAME IN
   ('user_profile','user_department','user_position','user_employee','user_employee_position','user_address')")
if [ "$table_count" -eq 6 ]; then
  MYSQL_PWD="$MYSQL_ROOT_PASSWORD" mysql --protocol=socket -uroot <<-EOSQL
GRANT SELECT, INSERT, UPDATE, DELETE ON user_db.user_profile TO 'ygh_user_app'@'%';
GRANT SELECT, INSERT, UPDATE, DELETE ON user_db.user_department TO 'ygh_user_app'@'%';
GRANT SELECT, INSERT, UPDATE, DELETE ON user_db.user_position TO 'ygh_user_app'@'%';
GRANT SELECT, INSERT, UPDATE, DELETE ON user_db.user_employee TO 'ygh_user_app'@'%';
GRANT SELECT, INSERT, UPDATE, DELETE ON user_db.user_employee_position TO 'ygh_user_app'@'%';
GRANT SELECT, INSERT, UPDATE, DELETE ON user_db.user_address TO 'ygh_user_app'@'%';
FLUSH PRIVILEGES;
EOSQL
fi
