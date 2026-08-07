#!/usr/bin/env bash
set -euo pipefail

REPO_PLATAFORMA="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
ENV_FILE="${ENV_FILE:-$REPO_PLATAFORMA/.env}"
DESTINO="${1:-}"

if [[ -z "$DESTINO" ]]; then
  echo "Uso: $0 /ruta/al/proyecto-real" >&2
  exit 64
fi

command -v realpath >/dev/null || { echo "Falta realpath." >&2; exit 69; }
[[ -f "$ENV_FILE" ]] || { echo "No existe $ENV_FILE." >&2; exit 66; }
[[ -d "$DESTINO/.git" || -f "$DESTINO/.git" ]] || {
  echo "La ruta no es un repositorio Git: $DESTINO" >&2
  exit 65
}

DESTINO="$(realpath "$DESTINO")"
if [[ "$DESTINO" == "$REPO_PLATAFORMA" ]]; then
  echo "El proyecto objetivo debe ser distinto del repositorio de plataforma." >&2
  exit 65
fi

git -C "$DESTINO" rev-parse --show-toplevel >/dev/null
tmp="${ENV_FILE}.tmp.$$"
umask 077
awk -v destino="$DESTINO" '
  BEGIN { actualizado=0 }
  /^AI_TARGET_REPO_DIR=/ {
    print "AI_TARGET_REPO_DIR=" destino
    actualizado=1
    next
  }
  { print }
  END {
    if (!actualizado) print "AI_TARGET_REPO_DIR=" destino
  }
' "$ENV_FILE" > "$tmp"
chmod 600 "$tmp"
mv -- "$tmp" "$ENV_FILE"

echo "Proyecto objetivo configurado: $DESTINO"
if [[ -f "$DESTINO/AGENTS.md" ]]; then
  echo "Instrucciones detectadas: $DESTINO/AGENTS.md"
else
  echo "Aviso: el proyecto no tiene AGENTS.md en su raíz." >&2
fi
echo "Siguiente control: ./scripts/verificar.sh 9"
