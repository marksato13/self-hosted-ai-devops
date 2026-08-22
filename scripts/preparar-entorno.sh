#!/usr/bin/env bash
set -euo pipefail

REPO_RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DESTINO="${ENV_DESTINO:-$REPO_RAIZ/.env}"

if [[ -e "$DESTINO" ]]; then
  echo "Ya existe $DESTINO; no se sobrescribe." >&2
  exit 73
fi

umask 077
mkdir -p "$(dirname "$DESTINO")" "$HOME/workspace" \
  "$HOME/.local/state/ai-devops/queue"
chmod 700 "$HOME/.local/state/ai-devops" \
  "$HOME/.local/state/ai-devops/queue"

tmp="${DESTINO}.tmp.$$"

awk -v home="$HOME" '
  { gsub("/home/CAMBIAR", home) }
  { print }
' "$REPO_RAIZ/.env.example" > "$tmp"

chmod 600 "$tmp"
mv -- "$tmp" "$DESTINO"
echo "Entorno preparado en $DESTINO con permisos 600."
echo "Ejecuta ./scripts/preparar-secretos.sh y agrega los secretos indicados antes de levantar Docker."
