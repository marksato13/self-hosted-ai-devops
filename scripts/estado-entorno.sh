#!/usr/bin/env bash
# Diagnóstico de solo lectura del stack de automatización y del proyecto.
set -euo pipefail
RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="${ENV_FILE:-$RAIZ/.env}"
[[ -f "$ENV_FILE" ]] && { set -a; source "$ENV_FILE"; set +a; }
OBJ="${AI_TARGET_REPO_DIR:-$HOME/workspace/${GITHUB_REPO:-ninjasec-platform}}"
PYMK="$OBJ/PY-MK"

estado_contenedor() {
  local nombre="$1"
  if ! docker inspect "$nombre" >/dev/null 2>&1; then printf '%s: no creado.\n' "$nombre"; return; fi
  docker inspect --format '{{.Name}}: {{.State.Status}} ({{if .State.Health}}{{.State.Health.Status}}{{else}}sin healthcheck{{end}}).' "$nombre" 2>/dev/null | sed 's#^/##'
}

printf 'Automatización:\n'; estado_contenedor omniroute; estado_contenedor openclaw-gateway
printf 'NinjaSec:\n'; estado_contenedor ninjasec-postgres; estado_contenedor ninjasec-backend; estado_contenedor ninjasec-frontend
printf 'Herramientas host: node=%s npm=%s python=%s.\n' "$(node --version 2>/dev/null || echo ausente)" "$(npm --version 2>/dev/null || echo ausente)" "$(python3 --version 2>/dev/null | awk '{print $2}' || echo ausente)"
if [[ -d "$PYMK/frontend" ]]; then
  [[ -d "$PYMK/frontend/node_modules" ]] && printf 'Frontend: dependencias instaladas.\n' || printf 'Frontend: node_modules ausente (aún no instalado).\n'
  [[ -f "$PYMK/frontend/package-lock.json" ]] && printf 'Frontend: package-lock presente.\n' || printf 'Frontend: package-lock ausente.\n'
fi
if [[ -f "$PYMK/backend/requirements.txt" ]]; then
  printf 'Backend: requirements.txt presente (%s paquetes declarados).\n' "$(grep -Ec '^[[:alnum:]_-]+[<=>~!]' "$PYMK/backend/requirements.txt" || true)"
fi
if [[ -f "$PYMK/.env" || -f "$PYMK/infra/.env" ]]; then printf 'Configuración NinjaSec: .env presente.\n'; else printf 'Configuración NinjaSec: falta .env (compose no puede arrancar aún).\n'; fi
