#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 2 ]]; then
  echo "Usage: $0 KEY_DIRECTORY KEY_ID" >&2
  exit 64
fi

key_directory="$(realpath -m -- "$1")"
key_id="$2"
if [[ ! "$key_id" =~ ^[A-Za-z0-9][A-Za-z0-9._-]{0,63}$ ]]; then
  echo "Unsafe key id." >&2
  exit 65
fi

umask 077
install -d -m 700 -- "$key_directory"
private_key="$key_directory/$key_id.private.pem"
public_key="$key_directory/$key_id.public.pem"
if [[ -e "$private_key" || -e "$public_key" ]]; then
  echo "Key files already exist; refusing to overwrite." >&2
  exit 73
fi

openssl genpkey -algorithm RSA -pkeyopt rsa_keygen_bits:3072 -out "$private_key"
openssl pkey -in "$private_key" -pubout -out "$public_key"
chmod 600 "$private_key"
chmod 644 "$public_key"
echo "Generated JWT key id $key_id in $key_directory"
