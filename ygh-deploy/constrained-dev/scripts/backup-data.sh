#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."
test -f .env || { echo '.env missing' >&2; exit 1; }

timestamp="$(date +%Y%m%d-%H%M%S)"
backup_root="${YGH_BACKUP_ROOT:-/opt/ygh/backups}"
backup_dir="${backup_root}/${timestamp}"
install -d -m 700 "$backup_dir"

compose=(docker compose --env-file .env -f vm-compose.yml --profile core --profile ai-data)
"${compose[@]}" exec -T mysql sh -c \
  'MYSQL_PWD="$MYSQL_ROOT_PASSWORD" exec mysqldump -uroot --all-databases --single-transaction --routines --events' \
  | gzip -9 >"${backup_dir}/mysql-all.sql.gz"

if docker inspect -f '{{.State.Running}}' ygh-vm-pgvector-1 2>/dev/null | grep -q true; then
  "${compose[@]}" exec -T pgvector \
    pg_dump -U ygh_vector -d ygh_vector -Fc >"${backup_dir}/pgvector.dump"
fi

if [[ -d "${YGH_KNOWLEDGE_STORAGE_PATH:-/opt/ygh/data/knowledge}" ]]; then
  tar -C "$(dirname "${YGH_KNOWLEDGE_STORAGE_PATH:-/opt/ygh/data/knowledge}")" -czf "${backup_dir}/knowledge-files.tar.gz" "$(basename "${YGH_KNOWLEDGE_STORAGE_PATH:-/opt/ygh/data/knowledge}")"
fi

sha256sum "${backup_dir}"/* >"${backup_dir}/SHA256SUMS"
chmod 600 "${backup_dir}"/*
echo "BACKUP_OK path=${backup_dir}"
