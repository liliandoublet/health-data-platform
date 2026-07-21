#!/usr/bin/env bash
# Genere sql/setup.local.sql en injectant les cles publiques RSA.
# setup.local.sql est gitignore : il est propre a ta machine.
set -euo pipefail

KEYDIR="${HOME}/.snowflake/keys"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

pubkey() { grep -v "^-----" "$1" | tr -d '\n'; }

LOADER_KEY="$(pubkey "${KEYDIR}/svc_loader.pub")"
DBT_KEY="$(pubkey "${KEYDIR}/svc_dbt.pub")"

sed -e "s|{{RSA_PUBLIC_KEY_LOADER}}|${LOADER_KEY}|" \
    -e "s|{{RSA_PUBLIC_KEY_DBT}}|${DBT_KEY}|" \
    "${HERE}/setup.sql" > "${HERE}/setup.local.sql"

echo "OK -> ${HERE}/setup.local.sql"
