#!/usr/bin/env bash
# ============================================================
#  publicar-stage.sh — pone la rama en un sitio mirable
# ============================================================
#  Compila el worktree de una tarea y lo sirve en un nginx local.
#  Con --tailnet, además lo publica en la red privada de Tailscale
#  para poder abrirlo desde el celular.
#
#  Uso:
#    ./scripts/publicar-stage.sh 12                 # solo local
#    ./scripts/publicar-stage.sh 12 --tailnet       # + URL para el celular
#    ./scripts/publicar-stage.sh 12 --agente docs
#
#  NUNCA abre un puerto en el router. Ver docs/decisiones.md ADR-017
# ============================================================
set -euo pipefail

ISSUE=""; AGENTE="backend"; TAILNET=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --tailnet) TAILNET=1; shift ;;
    --agente)  AGENTE="$2"; shift 2 ;;
    -h|--help) sed -n '2,18p' "$0"; exit 0 ;;
    *)         ISSUE="$1"; shift ;;
  esac
done

if [[ -z "$ISSUE" ]]; then
  echo "Uso: $0 <numero-de-issue> [--agente backend|tests|docs] [--tailnet]" >&2
  exit 1
fi

[[ "$ISSUE" =~ ^[0-9]+$ ]] || { echo "El issue debe ser numérico." >&2; exit 1; }
[[ "$AGENTE" =~ ^[a-z][a-z0-9-]*$ ]] || { echo "Agente inválido." >&2; exit 1; }

REPO_RAIZ="$(git rev-parse --show-toplevel)"
ORIGEN="$(dirname "$REPO_RAIZ")/worktrees/issue-${ISSUE}-${AGENTE}"
COMPOSE=(docker compose -f "${REPO_RAIZ}/infra/docker-compose.yml"
                        -f "${REPO_RAIZ}/infra/docker-compose.visual.yml")

set -a; source "${REPO_RAIZ}/.env"; set +a
STAGE_DIR="${STAGE_DIR:?falta STAGE_DIR en .env}"
STAGE_PORT="${STAGE_PORT:-8080}"

[[ -d "$ORIGEN" ]] || { echo "No existe el worktree ${ORIGEN}." >&2
                        echo "Crealo antes con: ./scripts/nueva-tarea.sh ${ISSUE}" >&2; exit 2; }

# ---------- 1. Compilar ----------
# Un sitio estático no necesita build; una app sí. El comando se
# declara en .env para no adivinar la herramienta del proyecto.
DIST="${ORIGEN}/${STAGE_DIST_DIR:-dist}"

if [[ -n "${STAGE_BUILD_CMD:-}" ]]; then
  echo "▶ Compilando ${AGENTE}…"
  ( cd "$ORIGEN" && eval "$STAGE_BUILD_CMD" ) || { echo "❌ El build falló." >&2; exit 3; }
elif [[ -f "${ORIGEN}/package.json" ]]; then
  echo "⚠️  Hay package.json pero STAGE_BUILD_CMD está vacío en .env." >&2
  echo "   Definilo (ej: 'npm ci && npm run build') o el stage servirá el código fuente." >&2
fi

[[ -d "$DIST" ]] || DIST="$ORIGEN"     # sitio estático: se sirve tal cual

# ---------- 2. Publicar en el directorio del stage ----------
# Se reemplaza entero: si una vuelta anterior dejó archivos que la
# nueva ya no genera, no deben seguir apareciendo en las capturas.
echo "▶ Publicando ${DIST} → ${STAGE_DIR}"
mkdir -p "$STAGE_DIR"
case "$STAGE_DIR" in
  /|"$HOME"|"$REPO_RAIZ")
    echo "STAGE_DIR apunta a una ruta protegida; se cancela." >&2
    exit 3
    ;;
esac
find "$STAGE_DIR" -mindepth 1 -maxdepth 1 -exec rm -rf -- {} +
cp -a "${DIST}/." "$STAGE_DIR/"

# ---------- 3. Levantar el stage ----------
"${COMPOSE[@]}" --profile visual up -d stage >/dev/null
for _ in $(seq 1 20); do
  curl -fsS "http://localhost:${STAGE_PORT}/salud" >/dev/null 2>&1 && break
  sleep 1
done
curl -fsS "http://localhost:${STAGE_PORT}/salud" >/dev/null 2>&1 \
  || { echo "❌ El stage no responde en :${STAGE_PORT}" >&2
       "${COMPOSE[@]}" logs stage --tail 20 >&2; exit 4; }

echo "✅ Stage local:  http://localhost:${STAGE_PORT}"

# ---------- 4. Publicar en la tailnet ----------
if [[ $TAILNET -eq 1 ]]; then
  command -v tailscale >/dev/null || { echo "tailscale no está instalado." >&2; exit 5; }
  # `serve` = solo tus dispositivos. `funnel` sería internet entero;
  # no se usa acá a propósito: el stage muestra trabajo sin terminar.
  sudo tailscale serve --bg --https 8443 "http://127.0.0.1:${STAGE_PORT}" >/dev/null
  HOST="$(tailscale status --json | jq -r '.Self.DNSName' | sed 's/\.$//')"
  echo "✅ Desde el celular: https://${HOST}:8443"
  echo "   (con Tailscale encendido; nadie fuera de tu tailnet lo ve)"
  echo "   Bajarlo:  sudo tailscale serve --https 8443 off"
fi
