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
