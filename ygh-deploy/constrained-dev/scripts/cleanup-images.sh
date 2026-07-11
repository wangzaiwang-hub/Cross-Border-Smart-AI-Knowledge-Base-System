#!/usr/bin/env bash
set -euo pipefail

echo 'Dangling images eligible for cleanup:'
docker image ls --filter dangling=true

if [[ "${1:-}" != '--apply' ]]; then
  echo 'DRY_RUN_ONLY use --apply to remove dangling images'
  exit 0
fi

docker image prune --force
echo DANGLING_IMAGE_CLEANUP_OK
