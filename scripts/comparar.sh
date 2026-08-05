#!/usr/bin/env bash
# ============================================================
#  comparar.sh — ¿cambió algo que no debía?
# ============================================================
#  Compara dos conjuntos de capturas píxel a píxel y pinta las
#  diferencias en rojo. Es la detección de regresión visual: lo
#  único del diseño que una máquina juzga sin equivocarse.
#
#  Uso:
#    ./scripts/comparar.sh base issue-12-v1
#    ./scripts/comparar.sh base issue-12-v1 0.5      # umbral en %
#
#  Códigos: 0 sin diferencias sobre el umbral · 1 hay que mirar · 2 error
# ============================================================
set -uo pipefail

ANTES="${1:-}"; DESPUES="${2:-}"; UMBRAL="${3:-${UMBRAL_VISUAL:-0.1}}"
[[ -z "$ANTES" || -z "$DESPUES" ]] && { echo "Uso: $0 <etiqueta-antes> <etiqueta-despues> [umbral%]" >&2; exit 2; }

REPO_RAIZ="$(git rev-parse --show-toplevel)"
set -a; source "${REPO_RAIZ}/.env"; set +a

echo "▶ ${ANTES} → ${DESPUES}  (umbral ${UMBRAL} %)"
docker compose -f "${REPO_RAIZ}/infra/docker-compose.yml" \
               -f "${REPO_RAIZ}/infra/docker-compose.visual.yml" \
               run --rm --no-deps shotter comparar.mjs \
               --antes   "/salida/${ANTES}" \
               --despues "/salida/${DESPUES}" \
               --umbral  "$UMBRAL"
exit $?
