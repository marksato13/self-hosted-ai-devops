#!/usr/bin/env bash
# ============================================================
#  verificar.sh — verificación automática del plan de ejecución
# ============================================================
#  Comprueba el estado real del sistema, tarea por tarea.
#  Es la contraparte ejecutable de docs/plan-ejecucion.md.
#
#  Uso:
#    ./scripts/verificar.sh 00      # el implementador — SE CORRE EN TU PC
#    ./scripts/verificar.sh 5       # verifica la fase 5
#    ./scripts/verificar.sh 11      # bucle visual
#    ./scripts/verificar.sh all     # las doce fases de la VM (no incluye la 00)
#
#  Salida: 0 si todo pasa, 1 si algo falla.
#  Pensado para que un agente lo corra y lea el código de salida.
# ============================================================
set -uo pipefail

ENV_FILE="${HOME}/self-hosted-ai-devops/.env"
[[ -f "$ENV_FILE" ]] && { set -a; source "$ENV_FILE"; set +a; }
REPO_PLATAFORMA="${HOME}/self-hosted-ai-devops"
REPO_OBJETIVO="${AI_TARGET_REPO_DIR:-}"

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

# Se corre en la PC, no en la VM: es la única fase de afuera.
fase00() {
  echo "── FASE 00 · El implementador (en tu PC) ──"
  chk T00A "Node.js 22 o superior"         'node --version | grep -qE "^v(2[2-9]|[3-9][0-9])\."'
  chk T00B "Codex CLI instalado"           'codex --version'
  manual T00C "Sesión de ChatGPT activa (codex login)"
  chk T00D "Repositorio clonado"           'test -f docs/plan-ejecucion.md'
  manual T00E "El implementador leyó el plan y dice T007"
}

fase0() {
  echo "── FASE 0 · Preparación ──"
  manual T001 "ISO de Ubuntu Server en el datastore"
  manual T002 "Suscripción de Codex disponible"
  manual T003 "Política sin rutas de pago revisada"
  manual T004 "Cuenta de Tailscale creada"
}

fase1() {
  echo "── FASE 1 · VM en ESXi ──"
  manual T005 "VM ai-devops creada"
  manual T006 "Snapshot 01-vm-vacia"
}

fase2() {
  echo "── FASE 2 · Ubuntu Server ──"
  chk T007 "Ubuntu LTS compatible instalado" 'grep -qE "VERSION_ID=\"(24.04|26.04)\"" /etc/os-release'
  chk T008 "Utilidades base instaladas"    'command -v git && command -v curl && command -v jq && command -v openssl'
  chk T009 "Firewall ufw activo"           'systemctl is-active --quiet ufw && grep -q "^ENABLED=yes" /etc/ufw/ufw.conf'
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
  echo "── FASE 5 · OmniRoute ──"
  chk T014 "Repositorio clonado"           'test -f "$HOME/self-hosted-ai-devops/infra/docker-compose.yml"'
  chk T015 "Permisos 600 en .env"          '[[ "$(stat -c %a "$ENV_FILE")" == "600" ]]'
  for k in OMNIROUTE_JWT_SECRET OMNIROUTE_API_KEY_SECRET OMNIROUTE_STORAGE_ENCRYPTION_KEY OMNIROUTE_INITIAL_PASSWORD; do
    chk T016 "Secreto local: $k"           "[[ -n \"\${$k:-}\" ]]"
  done
  chk T017 "Sin claves comerciales en .env" '! grep -qE "^(OPENAI|DEEPSEEK|DASHSCOPE|ZHIPU|MOONSHOT)_API_KEY=" "$ENV_FILE"'
  chk T018 "Gateway responde"              'curl -fsS http://localhost:20128/api/monitoring/health'
  chk T019 "Catálogo auto disponible"      'curl -fsS http://localhost:20128/v1/models | jq -e ".data[] | select(.id == \"auto/coding\")"'
  chk T019 "Ruta gratuita responde"        'curl -fsS --max-time 90 http://localhost:20128/v1/chat/completions \
    -H "Authorization: Bearer ${OMNIROUTE_API_KEY:-}" -H "Content-Type: application/json" \
    -d "{\"model\":\"auto/coding:free\",\"messages\":[{\"role\":\"user\",\"content\":\"Responde solamente OK\"}],\"max_tokens\":16}" \
    | grep -q "content.*OK"'
  manual T020 "Codex OAuth y proveedor gratuito conectados"
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
  chk T025 "Contenedor OmniRoute arriba"   'docker ps --format "{{.Names}}" | grep -qx omniroute'
  chk T025 "Contenedor openclaw arriba"    'docker ps --format "{{.Names}}" | grep -qx openclaw-gateway'
  chk T025 "Configuración OpenClaw válida" 'docker compose --env-file "$ENV_FILE" -f "$REPO_PLATAFORMA/infra/docker-compose.yml" run --rm -T --entrypoint node openclaw-gateway dist/index.js config validate'
  chk T025 "Telegram usa allowlist cerrada" 'jq -e '\''(.gateway.mode == "local") and (.channels.telegram.enabled == true) and (.channels.telegram.dmPolicy == "allowlist") and (.channels.telegram.allowFrom | length > 0) and (.channels.telegram.groupPolicy == "disabled")'\'' "${OPENCLAW_CONFIG_DIR}/openclaw.json"'
  chk T025 "Modelo usa OmniRoute local"      'jq -e '\''(.models.providers.omniroute.baseUrl == "http://omniroute:20128/v1") and (.agents.defaults.model.primary == "omniroute/oc/big-pickle")'\'' "${OPENCLAW_CONFIG_DIR}/openclaw.json"'
  chk T025 "Herramientas denegadas por defecto" 'jq -e '\''(.tools.allow | type == "array") and (.tools.allow | length == 0)'\'' "${OPENCLAW_CONFIG_DIR}/openclaw.json"'
  chk T025 "Plugin de control determinista cargado" 'docker exec openclaw-gateway node dist/index.js plugins inspect flota-control --runtime --json | jq -e '\''.plugin.status == "loaded" and (["aprobar","aprobar_todo","confirmar","flota","rechazar","a","c","todo","estado","sig","pausa","seguir","i","error"] - .commands | length == 0)'\'''
  chk T025 "Identidad Nexo instalada"       'grep -q "Name:.*Nexo" "${OPENCLAW_CONFIG_DIR}/workspace/IDENTITY.md" && test ! -f "${OPENCLAW_CONFIG_DIR}/workspace/BOOTSTRAP.md"'
  chk T025 "Gateway responde saludable"    'docker compose --env-file "$ENV_FILE" -f "$REPO_PLATAFORMA/infra/docker-compose.yml" exec -T openclaw-gateway node dist/index.js gateway health'
  manual T026 "El bot responde a tu cuenta"
  manual T027 "🔴 El bot IGNORA a otra cuenta"
}

fase8() {
  echo "── FASE 8 · Codex CLI ──"
  chk T028 "Codex instalado"               'codex --version'
  chk T029 "config.toml presente"          'test -f "$HOME/.codex/config.toml"'
  chk T029 "wire_api = responses"          'grep -q "wire_api = \"responses\"" "$HOME/.codex/config.toml"'
  chk T029 "Apunta al gateway local"       'grep -q "localhost:20128" "$HOME/.codex/config.toml"'
  chk T030 "Clave local de OmniRoute"      '[[ -n "${OMNIROUTE_API_KEY:-}" ]]'
  for p in planner backend tester docs reviewer; do
    chk T031 "Perfil definido: $p"         "test -f \"\$HOME/.codex/$p.config.toml\""
  done
}

fase9() {
  echo "── FASE 9 · GitHub y guardarraíles ──"
  chk T032 "Credencial de GitHub disponible" '[[ -n "${GITHUB_TOKEN:-}" ]] || gh auth status'
  chk T033 "gh autenticado"                'gh auth status'
  chk T034 "main protegida"                'gh api "repos/${GITHUB_OWNER:-marksato13}/${GITHUB_REPO:-self-hosted-ai-devops}/branches/main/protection"'
  chk T035 "gitleaks instalado"            'gitleaks version'
  chk T035 "hook de pre-commit instalado"  'test -f "$HOME/self-hosted-ai-devops/.git/hooks/pre-commit"'
  chk T036 "gitleaks detecta un secreto"   'd="$(mktemp -d)"; valor="sk-proj-$(openssl rand -hex 32)"; printf "OPENAI_API_KEY=%s\n" "$valor" > "$d/prueba.txt"; ! gitleaks detect --no-git --source "$d" --no-banner --redact'
  chk T037 "Repositorio objetivo configurado" '[[ -n "$REPO_OBJETIVO" && -d "$REPO_OBJETIVO/.git" ]]'
  manual T038 "PR abierto desde el celular"
  manual T039 "Snapshot 03-stack-completo"
}

fase10() {
  echo "── FASE 10 · La flota ──"
  chk T040 "scripts/nueva-tarea.sh ejecutable"      'test -x "$REPO_PLATAFORMA/scripts/nueva-tarea.sh"'
  chk T042 "scripts/integrar.sh ejecutable"         'test -x "$REPO_PLATAFORMA/scripts/integrar.sh"'
  chk T043 "scripts/limpiar-worktrees.sh ejecutable" 'test -x "$REPO_PLATAFORMA/scripts/limpiar-worktrees.sh"'
  chk T043 "Sin worktrees huérfanos" '[[ -n "$REPO_OBJETIVO" && -d "$REPO_OBJETIVO/.git" ]] && test "$(git -C "$REPO_OBJETIVO" worktree list | wc -l)" -eq 1'
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
  chk T057 "Perfil designer definido"      'test -f "$HOME/.codex/designer.config.toml"'
  chk T057 "Designer exige multimodal gratis" 'grep -q "auto/multimodal:free" "$HOME/.codex/designer.config.toml"'
  manual T057 "🔴 El modelo LEE la imagen (no solo responde)"
  chk T058 "scripts del bucle ejecutables" 'test -x "$REPO_PLATAFORMA/scripts/bucle-visual.sh"'
}

case "${1:-all}" in
  00|fase00) fase00 ;;
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
  # `all` cubre las fases de la VM. La 00 se pide aparte y a propósito:
  # se verifica en la PC, y desde la VM daría FALLA sin significar nada.
  all)       for f in 0 1 2 3 4 5 6 7 8 9 10 11; do "fase$f"; echo; done ;;
  *)
    echo "Uso: $0 <00|0-11|all>" >&2
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
