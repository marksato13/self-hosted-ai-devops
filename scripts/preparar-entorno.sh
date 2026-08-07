#!/usr/bin/env bash
set -euo pipefail

REPO_RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DESTINO="${ENV_DESTINO:-$REPO_RAIZ/.env}"

if [[ -e "$DESTINO" ]]; then
  echo "Ya existe $DESTINO; no se sobrescribe." >&2
  exit 73
fi

command -v openssl >/dev/null || { echo "Falta openssl." >&2; exit 69; }
umask 077
mkdir -p "$(dirname "$DESTINO")" "$HOME/workspace" \
  "$HOME/.openclaw" "$HOME/.local/state/ai-devops/queue"
chmod 700 "$HOME/.openclaw" "$HOME/.local/state/ai-devops" \
  "$HOME/.local/state/ai-devops/queue"

gateway="$(openssl rand -hex 32)"
jwt="$(openssl rand -base64 48 | tr -d '\n')"
api_secret="$(openssl rand -hex 32)"
storage="$(openssl rand -hex 32)"
password="$(openssl rand -base64 24 | tr -d '\n')"
tmp="${DESTINO}.tmp.$$"

awk -v home="$HOME" -v gateway="$gateway" -v jwt="$jwt" \
  -v api_secret="$api_secret" -v storage="$storage" -v password="$password" '
  { gsub("/home/CAMBIAR", home) }
  /^OMNIROUTE_JWT_SECRET=/ { print "OMNIROUTE_JWT_SECRET=" jwt; next }
  /^OMNIROUTE_API_KEY_SECRET=/ { print "OMNIROUTE_API_KEY_SECRET=" api_secret; next }
  /^OMNIROUTE_STORAGE_ENCRYPTION_KEY=/ { print "OMNIROUTE_STORAGE_ENCRYPTION_KEY=" storage; next }
  /^OMNIROUTE_INITIAL_PASSWORD=/ { print "OMNIROUTE_INITIAL_PASSWORD=" password; next }
  /^OPENCLAW_GATEWAY_TOKEN=/ { print "OPENCLAW_GATEWAY_TOKEN=" gateway; next }
  { print }
' "$REPO_RAIZ/.env.example" > "$tmp"

chmod 600 "$tmp"
mv -- "$tmp" "$DESTINO"
echo "Entorno preparado en $DESTINO con permisos 600."
echo "Telegram y la clave local de OmniRoute siguen vacíos a propósito."
