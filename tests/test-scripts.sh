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

HOME="$tmp/home" ENV_DESTINO="$tmp/config/.env" \
  "$REPO_RAIZ/scripts/preparar-entorno.sh" >/dev/null
test "$(stat -c %a "$tmp/config/.env")" = 600 || ((fallos+=1))
test "$(stat -c %a "$tmp/home/.local/state/ai-devops/queue")" = 700 || ((fallos+=1))
grep -q '^AI_SECRETS_DIR=' "$tmp/config/.env" || ((fallos+=1))
probar_fallo "no deja secretos en .env" grep -qE '(_TOKEN|_KEY)=[^[:space:]]+' "$tmp/config/.env"
probar_fallo "no sobrescribe un entorno existente" env HOME="$tmp/home" \
  ENV_DESTINO="$tmp/config/.env" "$REPO_RAIZ/scripts/preparar-entorno.sh"

if [[ $fallos -gt 0 ]]; then
  echo "$fallos pruebas fallaron." >&2
  exit 1
fi
echo "Todas las pruebas de scripts pasaron."
