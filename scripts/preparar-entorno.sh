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

master="sk-$(openssl rand -hex 24)"
postgres="$(openssl rand -hex 24)"
gateway="$(openssl rand -hex 32)"
tmp="${DESTINO}.tmp.$$"

awk -v home="$HOME" -v master="$master" -v postgres="$postgres" -v gateway="$gateway" '
  { gsub("/home/CAMBIAR", home) }
  /^LITELLM_MASTER_KEY=/ { print "LITELLM_MASTER_KEY=" master; next }
  /^POSTGRES_PASSWORD=/ { print "POSTGRES_PASSWORD=" postgres; next }
  /^OPENCLAW_GATEWAY_TOKEN=/ { print "OPENCLAW_GATEWAY_TOKEN=" gateway; next }
  { print }
' "$REPO_RAIZ/.env.example" > "$tmp"

chmod 600 "$tmp"
mv -- "$tmp" "$DESTINO"
echo "Entorno preparado en $DESTINO con permisos 600."
echo "Las claves de proveedores y Telegram siguen vacías a propósito."
