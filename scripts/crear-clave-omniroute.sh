#!/usr/bin/env bash
set -euo pipefail

REPO_RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="${ENV_DESTINO:-$REPO_RAIZ/.env}"
BASE_URL="${OMNIROUTE_BASE_URL:-http://127.0.0.1:20128}"

[[ -f "$ENV_FILE" ]] || { echo "No existe $ENV_FILE" >&2; exit 66; }
command -v curl >/dev/null || { echo "Falta curl." >&2; exit 69; }
command -v jq >/dev/null || { echo "Falta jq." >&2; exit 69; }

set -a
# shellcheck disable=SC1090
source "$ENV_FILE"
set +a
[[ -n "${OMNIROUTE_INITIAL_PASSWORD:-}" ]] || {
  echo "Falta OMNIROUTE_INITIAL_PASSWORD." >&2
  exit 78
}

umask 077
cookie_file="$(mktemp)"
response_file="$(mktemp)"
trap 'rm -f "$cookie_file" "$response_file"' EXIT

login_body="$(jq -cn --arg password "$OMNIROUTE_INITIAL_PASSWORD" '{password:$password}')"
curl -fsS -c "$cookie_file" -H 'Content-Type: application/json' \
  -d "$login_body" "$BASE_URL/api/auth/login" >/dev/null

create_body='{"name":"flota-codex","scopes":["chat"],"noLog":true}'
curl -fsS -b "$cookie_file" -H 'Content-Type: application/json' \
  -d "$create_body" "$BASE_URL/api/keys" > "$response_file"
new_key="$(jq -er '.key' "$response_file")"

tmp="${ENV_FILE}.tmp.$$"
awk -v key="$new_key" '
  BEGIN { replaced=0 }
  /^OMNIROUTE_API_KEY=/ { print "OMNIROUTE_API_KEY=" key; replaced=1; next }
  { print }
  END { if (!replaced) print "OMNIROUTE_API_KEY=" key }
' "$ENV_FILE" > "$tmp"
chmod 600 "$tmp"
mv -- "$tmp" "$ENV_FILE"
echo "Clave local de OmniRoute creada y guardada sin mostrarla."
