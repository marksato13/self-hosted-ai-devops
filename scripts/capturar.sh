#!/usr/bin/env bash
# ============================================================
#  capturar.sh — fotografía el stage
# ============================================================
#  Lanza Chromium headless dentro del contenedor `shotter` y deja
#  un PNG por ruta y viewport, más un informe de accesibilidad.
#
#  Uso:
#    ./scripts/capturar.sh antes
#    ./scripts/capturar.sh issue-12-v1
#
#  Salida:  $ARTEFACTOS_DIR/<etiqueta>/
#  Códigos: 0 capturó todo · 1 alguna ruta falló · 2 falta config
# ============================================================
set -euo pipefail

ETIQUETA="${1:-}"
[[ -z "$ETIQUETA" ]] && { echo "Uso: $0 <etiqueta>" >&2; exit 1; }

REPO_RAIZ="$(git rev-parse --show-toplevel)"
set -a; source "${REPO_RAIZ}/.env"; set +a
ARTEFACTOS_DIR="${ARTEFACTOS_DIR:?falta ARTEFACTOS_DIR en .env}"

if [[ ! -f "${REPO_RAIZ}/config/capturas.json" ]]; then
  echo "Falta config/capturas.json." >&2
  echo "Crealo con: cp config/capturas.json.example config/capturas.json" >&2
  exit 2
fi

mkdir -p "$ARTEFACTOS_DIR"

echo "▶ Capturando «${ETIQUETA}»…"
docker compose -f "${REPO_RAIZ}/infra/docker-compose.yml" \
               -f "${REPO_RAIZ}/infra/docker-compose.visual.yml" \
               run --rm shotter capturar.mjs --etiqueta "$ETIQUETA"
RC=$?

echo "  → ${ARTEFACTOS_DIR}/${ETIQUETA}"
exit $RC
