#!/usr/bin/env bash
set -euo pipefail

REPO_RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
fallos=0

probar_fallo() {
  local descripcion="$1"; shift
  if "$@" >/dev/null 2>&1; then
    echo "FALLA: $descripcion" >&2
    ((fallos+=1))
  else
    echo "OK: $descripcion"
  fi
}

for script in "$REPO_RAIZ"/scripts/*.sh; do
  bash -n "$script" || ((fallos+=1))
done

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/queue"
AI_QUEUE_DIR="$tmp/queue" "$REPO_RAIZ/scripts/solicitar-issue.sh" 12 >/dev/null
test -f "$tmp/queue/issue-12.pending" || ((fallos+=1))
probar_fallo "rechaza issue repetido" env AI_QUEUE_DIR="$tmp/queue" \
  "$REPO_RAIZ/scripts/solicitar-issue.sh" 12
probar_fallo "rechaza issue no numérico" env AI_QUEUE_DIR="$tmp/queue" \
  "$REPO_RAIZ/scripts/solicitar-issue.sh" '../main'
probar_fallo "ejecutor rechaza issue no numérico" \
  "$REPO_RAIZ/scripts/ejecutar-issue.sh" '*'

if [[ $fallos -gt 0 ]]; then
  echo "$fallos pruebas fallaron." >&2
  exit 1
fi
echo "Todas las pruebas de scripts pasaron."
