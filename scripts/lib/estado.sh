#!/usr/bin/env bash
# Primitivas de estado persistente. El llamador debe definir AI_STATE_DIR.

ai_estado_raiz() {
  printf '%s\n' "${AI_STATE_DIR:-$HOME/.local/state/ai-devops}"
}

ai_estado_preparar() {
  local raiz
  raiz="$(ai_estado_raiz)"
  umask 077
  mkdir -p "$raiz/issues" "$raiz/queue/completadas" "$raiz/queue/fallidas"
  chmod 700 "$raiz" "$raiz/issues" "$raiz/queue" \
    "$raiz/queue/completadas" "$raiz/queue/fallidas" 2>/dev/null || true
}

ai_evento() {
  local issue="$1" estado="$2" detalle="${3:-}"
  local raiz dir ahora
  raiz="$(ai_estado_raiz)"; dir="$raiz/issues/$issue"
  ahora="$(date --utc +%Y-%m-%dT%H:%M:%SZ)"
  mkdir -p "$dir"
  (
    flock -x 8
    jq -cn --arg ts "$ahora" --arg estado "$estado" --arg detalle "$detalle" \
      '{timestamp:$ts,estado:$estado,detalle:$detalle}' >> "$dir/events.jsonl"
  ) 8>"$dir/.events.lock"
}

# Los avisos son deliberadamente de "mejor esfuerzo": el estado durable se
# escribe antes y un fallo de Telegram nunca cambia el resultado del runner.
# Los textos se construyen aquí a partir de estados conocidos; no se envían
# prompts, logs, respuestas de proveedores ni detalles arbitrarios.
ai_notificar_estado() {
  local issue="$1" estado="$2" intento="${3:-0}"
  local raiz_repo reportador mensaje=""
  [[ "$issue" =~ ^[0-9]+$ ]] || return 0
  [[ "$intento" =~ ^[0-9]+$ ]] || intento=0

  case "$estado" in
    selected) mensaje="📥 Issue #$issue encolado automáticamente. Lo tomaré en el próximo ciclo." ;;
    queued) mensaje="🚀 Inicio del issue #$issue (intento $intento)." ;;
    planning) mensaje="🧭 Issue #$issue: preparando el plan de trabajo." ;;
    running) mensaje="🤖 Issue #$issue: agentes especializados trabajando en paralelo." ;;
    integrating) mensaje="🧩 Issue #$issue: integrando ramas y ejecutando verificaciones." ;;
    retrying) mensaje="🔁 Issue #$issue: fallo transitorio; habrá un reintento controlado (intento $intento)." ;;
    failed) mensaje="❌ Issue #$issue detenido tras agotar los reintentos. Los logs permanecen en la VM; usa «errores» en Telegram." ;;
    waiting_approval) mensaje="✅ Issue #$issue: PR listo. La CI debe quedar verde antes de la aprobación; te avisaré por Telegram." ;;
    ci_success) mensaje="🟢 Issue #$issue: CI aprobada. Ya puedes autorizar el PR desde Telegram." ;;
    ci_failed) mensaje="🔴 Issue #$issue: la CI falló. No se fusionará; los agentes deben corregirlo." ;;
    approved) mensaje="👍 Issue #$issue: aprobación registrada y ligada a la revisión actual." ;;
    completed|merged) mensaje="🎉 Issue #$issue: PR fusionado. El ciclo autónomo puede continuar con la siguiente tarea." ;;
    *) return 0 ;;
  esac

  raiz_repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
  reportador="$raiz_repo/scripts/reportar.sh"
  [[ -x "$reportador" ]] || return 0

  if ! timeout "${AI_NOTIFY_TIMEOUT_SECONDS:-20}" "$reportador" "$mensaje" \
      >/dev/null 2>&1; then
    ai_evento "$issue" notification_failed "no se pudo entregar el aviso de estado $estado"
  else
    ai_evento "$issue" notification_sent "aviso de estado $estado entregado"
  fi
  return 0
}

ai_notificar_agentes() {
  local issue="$1" agentes="$2" raiz_repo reportador
  [[ "$issue" =~ ^[0-9]+$ ]] || return 0
  # Solo nombres de perfiles esperables; nunca texto libre del plan.
  [[ "$agentes" =~ ^[a-z0-9_-]+([,][a-z0-9_-]+)*$ ]] || return 0
  raiz_repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
  reportador="$raiz_repo/scripts/reportar.sh"
  [[ -x "$reportador" ]] || return 0
  if ! timeout "${AI_NOTIFY_TIMEOUT_SECONDS:-20}" "$reportador" \
      "👥 Issue #$issue: roles asignados: ${agentes//,/, }." >/dev/null 2>&1; then
    ai_evento "$issue" notification_failed "no se pudo entregar el aviso de agentes"
  else
    ai_evento "$issue" notification_sent "aviso de agentes entregado"
  fi
  return 0
}

ai_notificar_pr() {
  local issue="$1" resultado="$2" raiz_repo reportador datos numero url mensaje
  [[ "$issue" =~ ^[0-9]+$ ]] || return 0
  [[ -n "${GITHUB_OWNER:-}" && -n "${GITHUB_REPO:-}" ]] || return 0
  command -v gh >/dev/null 2>&1 || return 0
  command -v jq >/dev/null 2>&1 || return 0
  datos="$(gh pr list --repo "$GITHUB_OWNER/$GITHUB_REPO" --state open \
    --head "integra/issue-$issue" --limit 1 --json number,url 2>/dev/null || true)"
  numero="$(jq -r '.[0].number // empty' <<<"$datos" 2>/dev/null || true)"
  url="$(jq -r '.[0].url // empty' <<<"$datos" 2>/dev/null || true)"
  [[ "$numero" =~ ^[0-9]+$ && "$url" == https://github.com/* ]] || return 0
  case "$resultado" in
    abierto) mensaje="📦 PR #$numero listo para el issue #$issue: $url. Esperando CI." ;;
    verde) mensaje="✅ PR #$numero con CI verde: $url. Responde «aprobar $numero» o «aprobar todo»." ;;
    rojo) mensaje="❌ PR #$numero con CI fallida: $url. No se fusionará; usa «errores $issue»." ;;
    *) return 0 ;;
  esac
  raiz_repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
  reportador="$raiz_repo/scripts/reportar.sh"
  [[ -x "$reportador" ]] || return 0
  if ! timeout "${AI_NOTIFY_TIMEOUT_SECONDS:-20}" "$reportador" "$mensaje" >/dev/null 2>&1; then
    ai_evento "$issue" notification_failed "no se pudo entregar el aviso del PR"
  else
    ai_evento "$issue" notification_sent "aviso del PR entregado"
  fi
}

ai_estado_guardar() {
  local issue="$1" estado="$2" intento="${3:-0}" detalle="${4:-}"
  local raiz dir ahora tmp
  raiz="$(ai_estado_raiz)"; dir="$raiz/issues/$issue"
  ahora="$(date --utc +%Y-%m-%dT%H:%M:%SZ)"
  mkdir -p "$dir"; tmp="$dir/.state.json.$$"
  jq -cn --argjson issue "$issue" --arg estado "$estado" \
    --argjson intento "$intento" --arg ts "$ahora" --arg detalle "$detalle" \
    '{version:1,issue:$issue,estado:$estado,intento:$intento,actualizado:$ts,detalle:$detalle}' > "$tmp"
  chmod 600 "$tmp"
  mv -f -- "$tmp" "$dir/state.json"
  ai_evento "$issue" "$estado" "$detalle"
  ai_notificar_estado "$issue" "$estado" "$intento"
}

ai_pausado() {
  [[ -f "$(ai_estado_raiz)/PAUSED" ]]
}

ai_pausar() {
  local raiz tmp
  raiz="$(ai_estado_raiz)"; ai_estado_preparar
  tmp="$raiz/.PAUSED.$$"
  printf '%s\n' "$(date --utc +%Y-%m-%dT%H:%M:%SZ)" > "$tmp"
  chmod 600 "$tmp"; mv -f -- "$tmp" "$raiz/PAUSED"
}

ai_reanudar() {
  rm -f -- "$(ai_estado_raiz)/PAUSED"
}
