#!/bin/sh
set -eu
: "${MYSQL_ROOT_PASSWORD:?required}" "${SYSTEM_DB_APP_PASSWORD:?required}" "${SYSTEM_DB_MIGRATION_PASSWORD:?required}"
validate(){ case "$1" in *[!A-Za-z0-9]*|'') exit 1;; esac; [ "${#1}" -ge 24 ]; }
validate "$SYSTEM_DB_APP_PASSWORD";validate "$SYSTEM_DB_MIGRATION_PASSWORD"
MYSQL_PWD="$MYSQL_ROOT_PASSWORD" mysql --protocol=socket -uroot <<-EOSQL
CREATE DATABASE IF NOT EXISTS system_db CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci;
CREATE USER IF NOT EXISTS 'ygh_system_app'@'%' IDENTIFIED BY '${SYSTEM_DB_APP_PASSWORD}';
ALTER USER 'ygh_system_app'@'%' IDENTIFIED BY '${SYSTEM_DB_APP_PASSWORD}';
CREATE USER IF NOT EXISTS 'ygh_system_migration'@'%' IDENTIFIED BY '${SYSTEM_DB_MIGRATION_PASSWORD}';
ALTER USER 'ygh_system_migration'@'%' IDENTIFIED BY '${SYSTEM_DB_MIGRATION_PASSWORD}';
REVOKE ALL PRIVILEGES, GRANT OPTION FROM 'ygh_system_app'@'%';
REVOKE ALL PRIVILEGES, GRANT OPTION FROM 'ygh_system_migration'@'%';
GRANT SELECT,INSERT,UPDATE,DELETE,CREATE,DROP,REFERENCES,INDEX,ALTER ON system_db.* TO 'ygh_system_migration'@'%';
FLUSH PRIVILEGES;
EOSQL
count=$(MYSQL_PWD="$MYSQL_ROOT_PASSWORD" mysql --protocol=socket -uroot -Nse "SELECT COUNT(*) FROM information_schema.TABLES WHERE TABLE_SCHEMA='system_db' AND TABLE_NAME IN ('system_role','system_permission','system_role_permission','system_user_authorization','system_user_role','system_authorization_audit','system_dictionary_type','system_dictionary_item','system_setting','system_feature_flag','system_configuration_audit')")
if [ "$count" -eq 11 ];then MYSQL_PWD="$MYSQL_ROOT_PASSWORD" mysql --protocol=socket -uroot <<-EOSQL
GRANT SELECT,INSERT,UPDATE,DELETE ON system_db.system_role TO 'ygh_system_app'@'%';
GRANT SELECT,INSERT,UPDATE,DELETE ON system_db.system_permission TO 'ygh_system_app'@'%';
GRANT SELECT,INSERT,UPDATE,DELETE ON system_db.system_role_permission TO 'ygh_system_app'@'%';
GRANT SELECT,INSERT,UPDATE,DELETE ON system_db.system_user_authorization TO 'ygh_system_app'@'%';
GRANT SELECT,INSERT,UPDATE,DELETE ON system_db.system_user_role TO 'ygh_system_app'@'%';
GRANT SELECT,INSERT,UPDATE,DELETE ON system_db.system_authorization_audit TO 'ygh_system_app'@'%';
GRANT SELECT,INSERT,UPDATE,DELETE ON system_db.system_dictionary_type TO 'ygh_system_app'@'%';
GRANT SELECT,INSERT,UPDATE,DELETE ON system_db.system_dictionary_item TO 'ygh_system_app'@'%';
GRANT SELECT,INSERT,UPDATE,DELETE ON system_db.system_setting TO 'ygh_system_app'@'%';
GRANT SELECT,INSERT,UPDATE,DELETE ON system_db.system_feature_flag TO 'ygh_system_app'@'%';
GRANT SELECT,INSERT,UPDATE,DELETE ON system_db.system_configuration_audit TO 'ygh_system_app'@'%';
FLUSH PRIVILEGES;
EOSQL
fi
