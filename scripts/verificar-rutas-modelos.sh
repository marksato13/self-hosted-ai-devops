#!/usr/bin/env bash
# Comprueba que las rutas configuradas existan en el catálogo local de OmniRoute.
set -euo pipefail

REPO_RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="${ENV_FILE:-$REPO_RAIZ/.env}"
[[ -f "$ENV_FILE" ]] && { set -a; source "$ENV_FILE"; set +a; }

declare -a rutas=("$@")
if (( ${#rutas[@]} == 0 )); then
  for variable in CODEX_PLANNER_MODELS CODEX_BACKEND_MODELS CODEX_TESTS_MODELS CODEX_DOCS_MODELS; do
    [[ -n "${!variable:-}" ]] || continue
    IFS=',' read -r -a configuradas <<<"${!variable}"
    rutas+=("${configuradas[@]}")
  done
fi

if (( ${#rutas[@]} == 0 )); then
  echo "No hay rutas personalizadas configuradas; se usan los fallbacks seguros por defecto."
  exit 0
fi
command -v curl >/dev/null || { echo "Falta curl." >&2; exit 69; }
command -v jq >/dev/null || { echo "Falta jq." >&2; exit 69; }
[[ -n "${OMNIROUTE_API_KEY:-}" ]] || { echo "Falta OMNIROUTE_API_KEY." >&2; exit 78; }

for ruta in "${rutas[@]}"; do
  [[ "$ruta" =~ ^[A-Za-z0-9][A-Za-z0-9._:/-]*$ ]] || {
    echo "Ruta inválida: $ruta" >&2
    exit 64
  }
done

puerto="${OMNIROUTE_PORT:-20128}"
[[ "$puerto" =~ ^[1-9][0-9]{0,4}$ ]] || { echo "OMNIROUTE_PORT inválido." >&2; exit 64; }
catalogo="$(mktemp)"
trap 'rm -f -- "$catalogo"' EXIT
curl -fsS --max-time "${OMNIROUTE_MODELS_TIMEOUT_SECONDS:-15}" \
  -H "Authorization: Bearer $OMNIROUTE_API_KEY" \
  "http://127.0.0.1:${puerto}/v1/models" >"$catalogo"

faltan=0
for ruta in "${rutas[@]}"; do
  if jq -e --arg ruta "$ruta" '.data | any(.[]; .id == $ruta)' "$catalogo" >/dev/null; then
    echo "OK: $ruta"
  else
    echo "FALTA: $ruta" >&2
    faltan=1
  fi
done
exit "$faltan"
