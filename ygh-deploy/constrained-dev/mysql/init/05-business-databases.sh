#!/bin/sh
set -eu

: "${MYSQL_ROOT_PASSWORD:?required}"

validate_password() {
  case "$1" in *[!A-Za-z0-9]*|'') echo "database passwords must be alphanumeric" >&2; exit 1;; esac
  [ "${#1}" -ge 24 ] || { echo "database passwords must contain at least 24 characters" >&2; exit 1; }
}

provision() {
  service="$1"; database="$2"; app_password="$3"; migration_password="$4"
  validate_password "$app_password"
  validate_password "$migration_password"
  MYSQL_PWD="$MYSQL_ROOT_PASSWORD" mysql --protocol=socket -uroot <<-EOSQL
CREATE DATABASE IF NOT EXISTS ${database} CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci;
CREATE USER IF NOT EXISTS 'ygh_${service}_app'@'%' IDENTIFIED BY '${app_password}';
ALTER USER 'ygh_${service}_app'@'%' IDENTIFIED BY '${app_password}';
CREATE USER IF NOT EXISTS 'ygh_${service}_migration'@'%' IDENTIFIED BY '${migration_password}';
ALTER USER 'ygh_${service}_migration'@'%' IDENTIFIED BY '${migration_password}';
REVOKE ALL PRIVILEGES, GRANT OPTION FROM 'ygh_${service}_app'@'%';
REVOKE ALL PRIVILEGES, GRANT OPTION FROM 'ygh_${service}_migration'@'%';
GRANT SELECT,INSERT,UPDATE,DELETE ON ${database}.* TO 'ygh_${service}_app'@'%';
GRANT SELECT,INSERT,UPDATE,DELETE,CREATE,DROP,REFERENCES,INDEX,ALTER ON ${database}.* TO 'ygh_${service}_migration'@'%';
FLUSH PRIVILEGES;
EOSQL
}

provision product product_db "${YGH_PRODUCT_DB_APP_PASSWORD:?required}" "${YGH_PRODUCT_DB_MIGRATION_PASSWORD:?required}"
provision inventory inventory_db "${YGH_INVENTORY_DB_APP_PASSWORD:?required}" "${YGH_INVENTORY_DB_MIGRATION_PASSWORD:?required}"
provision order order_db "${YGH_ORDER_DB_APP_PASSWORD:?required}" "${YGH_ORDER_DB_MIGRATION_PASSWORD:?required}"
provision wallet wallet_db "${YGH_WALLET_DB_APP_PASSWORD:?required}" "${YGH_WALLET_DB_MIGRATION_PASSWORD:?required}"
provision knowledge knowledge_db "${YGH_KNOWLEDGE_DB_APP_PASSWORD:?required}" "${YGH_KNOWLEDGE_DB_MIGRATION_PASSWORD:?required}"
provision ai ai_db "${YGH_AI_DB_APP_PASSWORD:?required}" "${YGH_AI_DB_MIGRATION_PASSWORD:?required}"
provision training training_db "${YGH_TRAINING_DB_APP_PASSWORD:?required}" "${YGH_TRAINING_DB_MIGRATION_PASSWORD:?required}"
provision notification notification_db "${YGH_NOTIFICATION_DB_APP_PASSWORD:?required}" "${YGH_NOTIFICATION_DB_MIGRATION_PASSWORD:?required}"
