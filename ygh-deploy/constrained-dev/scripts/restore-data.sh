#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."
backup_dir="${1:-}"
[[ -n "$backup_dir" && -d "$backup_dir" ]] || { echo 'usage: restore-data.sh BACKUP_DIR --confirm' >&2; exit 2; }
[[ "${2:-}" == '--confirm' ]] || { echo 'restore is destructive; append --confirm' >&2; exit 2; }
test -f .env || { echo '.env missing' >&2; exit 1; }
(cd "$backup_dir" && sha256sum -c SHA256SUMS)

compose=(docker compose --env-file .env -f vm-compose.yml --profile core --profile ai-data)
gzip -dc "$backup_dir/mysql-all.sql.gz" | "${compose[@]}" exec -T mysql sh -c 'MYSQL_PWD="$MYSQL_ROOT_PASSWORD" mysql -uroot'
if [[ -f "$backup_dir/pgvector.dump" ]]; then
  "${compose[@]}" exec -T pgvector dropdb -U ygh_vector --if-exists ygh_vector
  "${compose[@]}" exec -T pgvector createdb -U ygh_vector ygh_vector
  cat "$backup_dir/pgvector.dump" | "${compose[@]}" exec -T pgvector pg_restore -U ygh_vector -d ygh_vector --clean --if-exists
fi
if [[ -f "$backup_dir/knowledge-files.tar.gz" ]]; then
  knowledge_path="${YGH_KNOWLEDGE_STORAGE_PATH:-/opt/ygh/data/knowledge}"
  case "$knowledge_path" in
    /opt/ygh/data/*) ;;
    *) echo "knowledge restore path must stay under /opt/ygh/data" >&2; exit 2 ;;
  esac
  install -d -m 750 "$(dirname "$knowledge_path")"
  if [[ -e "$knowledge_path" ]]; then
    mv "$knowledge_path" "${knowledge_path}.before-restore-$(date +%Y%m%d-%H%M%S)"
  fi
  tar -C "$(dirname "$knowledge_path")" -xzf "$backup_dir/knowledge-files.tar.gz"
fi
echo "RESTORE_OK source=${backup_dir}"
