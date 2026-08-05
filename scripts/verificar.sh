#!/usr/bin/env bash
# ============================================================
#  verificar.sh — verificación automática del plan de ejecución
# ============================================================
#  Comprueba el estado real del sistema, tarea por tarea.
#  Es la contraparte ejecutable de docs/plan-ejecucion.md.
#
#  Uso:
#    ./scripts/verificar.sh 5       # verifica la fase 5
#    ./scripts/verificar.sh 11      # bucle visual
#    ./scripts/verificar.sh all     # las doce fases
#
#  Salida: 0 si todo pasa, 1 si algo falla.
#  Pensado para que un agente lo corra y lea el código de salida.
# ============================================================
set -uo pipefail

ENV_FILE="${HOME}/self-hosted-ai-devops/.env"
[[ -f "$ENV_FILE" ]] && { set -a; source "$ENV_FILE"; set +a; }

OK=0; FALLO=0; OMITIDO=0

verde()  { printf '\033[32m%s\033[0m\n' "$1"; }
rojo()   { printf '\033[31m%s\033[0m\n' "$1"; }
gris()   { printf '\033[90m%s\033[0m\n' "$1"; }

# chk <id> <descripción> <comando…>
chk() {
  local id="$1" desc="$2"; shift 2
  printf '  %-6s %-46s ' "$id" "$desc"
  if eval "$@" >/dev/null 2>&1; then
    verde "OK"; ((OK++))
  else
    rojo "FALLA"; ((FALLO++))
  fi
}

# manual <id> <descripción> — requiere una persona, no se automatiza
manual() {
  printf '  %-6s %-46s ' "$1" "$2"
  gris "manual"; ((OMITIDO++))
}

fase0() {
  echo "── FASE 0 · Preparación ──"
  manual T001 "ISO de Ubuntu Server en el datastore"
  manual T002 "Cuatro claves de API obtenidas"
  manual T003 "Topes de gasto en las cuatro consolas"
  manual T004 "Cuenta de Tailscale creada"
}

fase1() {
  echo "── FASE 1 · VM en ESXi ──"
  manual T005 "VM ai-devops creada"
  manual T006 "Snapshot 01-vm-vacia"
}

fase2() {
  echo "── FASE 2 · Ubuntu Server ──"
  chk T007 "Ubuntu 24.04 instalado"        'lsb_release -ds | grep -q "24.04"'
  chk T008 "Utilidades base instaladas"    'command -v git && command -v curl && command -v jq && command -v openssl'
  chk T009 "Firewall ufw activo"           'sudo -n ufw status 2>/dev/null | grep -q "Status: active"'
}

fase3() {
  echo "── FASE 3 · Tailscale ──"
  chk T010 "Tailscale conectado"           'tailscale ip -4'
  manual T011 "SSH desde el celular sin WiFi"
}

fase4() {
  echo "── FASE 4 · Docker ──"
  chk T012 "Docker sin sudo"               'docker ps'
  chk T012 "Docker Compose disponible"     'docker compose version'
  manual T013 "Snapshot 02-base-lista"
}

fase5() {
  echo "── FASE 5 · LiteLLM ──"
  chk T014 "Repositorio clonado"           'test -f "$HOME/self-hosted-ai-devops/infra/litellm-config.yaml"'
  chk T015 "Permisos 600 en .env"          '[[ "$(stat -c %a "$ENV_FILE")" == "600" ]]'
  chk T016 "LITELLM_MASTER_KEY generada"   '[[ -n "${LITELLM_MASTER_KEY:-}" && ${#LITELLM_MASTER_KEY} -ge 20 ]]'
  chk T016 "POSTGRES_PASSWORD generada"    '[[ -n "${POSTGRES_PASSWORD:-}" ]]'
  for k in OPENAI_API_KEY DEEPSEEK_API_KEY DASHSCOPE_API_KEY ZHIPU_API_KEY; do
    chk T017 "Clave presente: $k"          "[[ -n \"\${$k:-}\" ]]"
  done
  chk T018 "Gateway responde"              'curl -fsS http://localhost:4000/health/liveliness'
  for m in planner backend tester docs reviewer; do
    chk T019 "Modelo responde: $m" "curl -fsS http://localhost:4000/v1/chat/completions \
      -H 'Authorization: Bearer ${LITELLM_MASTER_KEY:-}' -H 'Content-Type: application/json' \
      -d '{\"model\":\"$m\",\"messages\":[{\"role\":\"user\",\"content\":\"ok\"}]}' \
      | jq -e '.choices[0].message.content'"
  done
  chk T020 "Claves virtuales creadas" "curl -fsS http://localhost:4000/key/list \
    -H 'Authorization: Bearer ${LITELLM_MASTER_KEY:-}' | jq -e '.keys | length >= 5'"
}

fase6() {
  echo "── FASE 6 · Telegram ──"
  manual T021 "Bot creado en BotFather"
  manual T022 "chat_id obtenido"
  chk T023 "Token de Telegram en .env"     '[[ "${TELEGRAM_BOT_TOKEN:-}" == *:* ]]'
  chk T023 "Allowlist de chat_id definida" '[[ "${TELEGRAM_ALLOWED_CHAT_IDS:-}" =~ ^[0-9] ]]'
}

fase7() {
  echo "── FASE 7 · OpenClaw ──"
  chk T024 "OPENCLAW_IMAGE definida"       '[[ -n "${OPENCLAW_IMAGE:-}" ]]'
  chk T025 "Contenedor postgres arriba"    'docker ps --format "{{.Names}}" | grep -q litellm-db'
  chk T025 "Contenedor litellm arriba"     'docker ps --format "{{.Names}}" | grep -qx litellm'
  chk T025 "Contenedor openclaw arriba"    'docker ps --format "{{.Names}}" | grep -qx openclaw'
  manual T026 "El bot responde a tu cuenta"
  manual T027 "🔴 El bot IGNORA a otra cuenta"
}

fase8() {
  echo "── FASE 8 · Codex CLI ──"
  chk T028 "Codex instalado"               'codex --version'
  chk T029 "config.toml presente"          'test -f "$HOME/.codex/config.toml"'
  chk T029 "wire_api = responses"          'grep -q "wire_api = \"responses\"" "$HOME/.codex/config.toml"'
  chk T029 "Apunta al gateway local"       'grep -q "localhost:4000" "$HOME/.codex/config.toml"'
  chk T030 "Variables en el entorno"       '[[ -n "${LITELLM_MASTER_KEY:-}" ]]'
  for p in planner backend tester docs reviewer; do
    chk T031 "Perfil definido: $p"         "grep -q '\[profiles.$p\]' \"\$HOME/.codex/config.toml\""
  done
}

fase9() {
  echo "── FASE 9 · GitHub y guardarraíles ──"
  chk T032 "GITHUB_TOKEN en .env"          '[[ -n "${GITHUB_TOKEN:-}" ]]'
  chk T033 "gh autenticado"                'gh auth status'
  chk T034 "main protegida"                'gh api "repos/${GITHUB_OWNER:-marksato13}/${GITHUB_REPO:-self-hosted-ai-devops}/branches/main/protection"'
  chk T035 "gitleaks instalado"            'gitleaks version'
  chk T035 "hook de pre-commit instalado"  'test -f "$HOME/self-hosted-ai-devops/.git/hooks/pre-commit"'
  chk T036 "gitleaks detecta un secreto"   'printf "OPENAI_API_KEY=sk-proj-falsaparaprobar1234567890abcdef\n" > /tmp/_gl.txt; ! gitleaks detect --no-git --source /tmp/_gl.txt --no-banner; rc=$?; rm -f /tmp/_gl.txt; test $rc -eq 0'
  chk T037 "Workspace preparado"           'test -x "$HOME/workspace/self-hosted-ai-devops/scripts/nueva-tarea.sh"'
  manual T038 "PR abierto desde el celular"
  manual T039 "Snapshot 03-stack-completo"
}

fase10() {
  echo "── FASE 10 · La flota ──"
  chk T040 "scripts/nueva-tarea.sh ejecutable"      'test -x "$HOME/workspace/self-hosted-ai-devops/scripts/nueva-tarea.sh"'
  chk T042 "scripts/integrar.sh ejecutable"         'test -x "$HOME/workspace/self-hosted-ai-devops/scripts/integrar.sh"'
  chk T043 "scripts/limpiar-worktrees.sh ejecutable" 'test -x "$HOME/workspace/self-hosted-ai-devops/scripts/limpiar-worktrees.sh"'
  chk T043 "Sin worktrees huérfanos" 'test "$(git -C "$HOME/workspace/self-hosted-ai-devops" worktree list | wc -l)" -eq 1'
  manual T044 "Ciclo completo desde Telegram"
  manual T045 "Checklist de seguridad repasado"
}

fase11() {
  echo "── FASE 11 · Bucle visual ──"
  chk T046 "STAGE_DIR existe"              '[[ -d "${STAGE_DIR:-/nada}" ]]'
  chk T046 "ARTEFACTOS_DIR existe"         '[[ -d "${ARTEFACTOS_DIR:-/nada}" ]]'
  chk T047 "Imagen shotter construida"     'docker image inspect shotter:local'
  chk T048 "Chromium renderiza sin X11"    'test -s "${ARTEFACTOS_DIR:-/nada}/prueba-headless.png"'
  chk T049 "config/capturas.json presente" 'jq -e ".rutas | length >= 1" "$HOME/self-hosted-ai-devops/config/capturas.json"'
  chk T050 "Stage responde"                'curl -fsS "http://localhost:${STAGE_PORT:-8080}/salud"'
  manual T051 "Stage abierto desde el celular"
  chk T052 "Hay capturas"                  'ls "${ARTEFACTOS_DIR:-/nada}"/*/*.png >/dev/null 2>&1'
  chk T053 "Línea base fijada"             'test -d "${ARTEFACTOS_DIR:-/nada}/base"'
  chk T054 "El comparador detecta cambios" 'test -d "${ARTEFACTOS_DIR:-/nada}/cambiado/diff"'
  manual T055 "Imagen recibida en Telegram"
  chk T056 "WHATSAPP_MODO definido"        '[[ "${WHATSAPP_MODO:-}" =~ ^(off|cloud|openclaw)$ ]]'
  chk T057 "Perfil designer definido"      'grep -q "\[profiles.designer\]" "$HOME/.codex/config.toml"'
  chk T057 "Alias designer en el gateway"  'grep -q "model_name: designer" "$HOME/self-hosted-ai-devops/infra/litellm-config.yaml"'
  manual T057 "🔴 El modelo LEE la imagen (no solo responde)"
  chk T058 "scripts del bucle ejecutables" 'test -x "$HOME/workspace/self-hosted-ai-devops/scripts/bucle-visual.sh"'
}

case "${1:-all}" in
  0|fase0)   fase0 ;;
  1|fase1)   fase1 ;;
  2|fase2)   fase2 ;;
  3|fase3)   fase3 ;;
  4|fase4)   fase4 ;;
  5|fase5)   fase5 ;;
  6|fase6)   fase6 ;;
  7|fase7)   fase7 ;;
  8|fase8)   fase8 ;;
  9|fase9)   fase9 ;;
  10|fase10) fase10 ;;
  11|fase11) fase11 ;;
  all)       for f in 0 1 2 3 4 5 6 7 8 9 10 11; do "fase$f"; echo; done ;;
  *)
    echo "Uso: $0 <0-11|all>" >&2
    exit 64
    ;;
esac

echo
echo "─────────────────────────────────────"
printf '  OK: %d   ' "$OK"
[[ $FALLO -gt 0 ]] && printf 'FALLAN: %d   ' "$FALLO"
printf 'manuales: %d\n' "$OMITIDO"

if [[ $FALLO -gt 0 ]]; then
  echo
  rojo "  No continuar a la siguiente fase hasta resolver los fallos."
  echo "  Diagnóstico: docs/runbook.md"
  exit 1
fi

[[ $OMITIDO -gt 0 ]] && gris "  Las tareas 'manual' requieren verificación de una persona."
exit 0
