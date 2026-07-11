#!/usr/bin/env bash
set -euo pipefail

if [[ "$(id -u)" -ne 0 ]]; then
  echo "Run as root" >&2
  exit 1
fi

for port in 3306 5432 6379 8080 8848 9848; do
  rule="rule family=ipv4 source address=192.168.154.1/32 port port=${port} protocol=tcp accept"
  firewall-cmd --permanent --query-rich-rule="$rule" >/dev/null || \
    firewall-cmd --permanent --add-rich-rule="$rule" >/dev/null
done
firewall-cmd --reload >/dev/null
echo VM_FIREWALL_OK
