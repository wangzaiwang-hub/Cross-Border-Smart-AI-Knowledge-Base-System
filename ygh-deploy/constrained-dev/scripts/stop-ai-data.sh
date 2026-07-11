#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."
docker compose --env-file .env -f vm-compose.yml --profile ai-data stop pgvector
echo AI_DATA_STOPPED_VOLUME_PRESERVED
