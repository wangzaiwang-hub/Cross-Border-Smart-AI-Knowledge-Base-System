#!/usr/bin/env bash
set -euo pipefail

disk_used=$(df -P / | awk 'NR==2 {gsub("%","",$5); print $5}')
available_mib=$(awk '/MemAvailable/ {printf "%d", $2/1024}' /proc/meminfo)
docker_bytes=$(docker system df --format '{{json .}}' 2>/dev/null | wc -c)
echo "RESOURCE_STATUS disk_used_percent=${disk_used} available_memory_mib=${available_mib} docker_report_bytes=${docker_bytes}"
if (( disk_used >= 80 )); then echo 'DISK_WATERMARK_EXCEEDED' >&2; exit 1; fi
if (( available_mib < 500 )); then echo 'LOW_AVAILABLE_MEMORY' >&2; exit 1; fi
