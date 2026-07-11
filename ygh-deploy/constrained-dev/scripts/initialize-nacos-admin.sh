#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."
set -a
# shellcheck disable=SC1091
source .env
set +a

response_file="$(mktemp)"
trap 'rm -f "$response_file"' EXIT
nacos_base_url="http://192.168.154.10:8848"

code="$(curl -sS -o "$response_file" -w '%{http_code}' \
  -X POST "${nacos_base_url}/nacos/v3/auth/user/admin" \
  --data-urlencode "password=${NACOS_ADMIN_PASSWORD}")"

if [[ "$code" =~ ^2 ]]; then
  :
elif grep -Eqi 'exist|initialized|already' "$response_file"; then
  :
else
  echo "NACOS_ADMIN_INIT_FAILED http=$code" >&2
  exit 1
fi

login_code="$(curl -sS -o "$response_file" -w '%{http_code}' \
  -X POST "${nacos_base_url}/nacos/v3/auth/user/login" \
  --data-urlencode 'username=nacos' \
  --data-urlencode "password=${NACOS_ADMIN_PASSWORD}")"

if [[ "$login_code" =~ ^2 ]] && grep -q 'accessToken' "$response_file"; then
  echo NACOS_ADMIN_LOGIN_OK
else
  echo "NACOS_ADMIN_LOGIN_FAILED http=$login_code" >&2
  exit 1
fi
