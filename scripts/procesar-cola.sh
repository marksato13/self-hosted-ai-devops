#!/usr/bin/env bash
set -euo pipefail

REPO_RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="${ENV_FILE:-$REPO_RAIZ/.env}"
set -a
[[ -f "$ENV_FILE" ]] && source "$ENV_FILE"
set +a
# shellcheck source=scripts/lib/estado.sh
source "$REPO_RAIZ/scripts/lib/estado.sh"

QUEUE="${AI_QUEUE_DIR:-$HOME/.local/state/ai-devops/queue}"
AI_STATE_DIR="${AI_STATE_DIR:-$HOME/.local/state/ai-devops}"
MAX_RETRIES="${MAX_RETRIES_PER_TASK:-2}"
RETRY_DELAY="${AI_RETRY_DELAY_SECONDS:-60}"
[[ "$MAX_RETRIES" =~ ^[0-9]+$ ]] || { echo "MAX_RETRIES_PER_TASK inválido." >&2; exit 64; }
[[ "$RETRY_DELAY" =~ ^[0-9]+$ ]] || { echo "AI_RETRY_DELAY_SECONDS inválido." >&2; exit 64; }
ai_estado_preparar
mkdir -p "$QUEUE" "$QUEUE/completadas" "$QUEUE/fallidas"
exec 9>"$QUEUE/.procesador.lock"
flock -n 9 || { echo "Ya hay otro procesador activo." >&2; exit 75; }

reconciliar_ci() {
  local archivo issue estado intento pr_json total incompletos fallidos
  command -v gh >/dev/null 2>&1 || return 0
  command -v jq >/dev/null 2>&1 || return 0
  [[ -n "${GITHUB_OWNER:-}" && -n "${GITHUB_REPO:-}" ]] || return 0
  shopt -s nullglob
  for archivo in "$AI_STATE_DIR"/issues/*/state.json; do
    estado="$(jq -r '.estado // empty' "$archivo" 2>/dev/null || true)"
    [[ "$estado" == waiting_approval || "$estado" == ci_failed ]] || continue
    issue="$(jq -r '.issue // empty' "$archivo" 2>/dev/null || true)"
    intento="$(jq -r '.intento // 0' "$archivo" 2>/dev/null || true)"
    [[ "$issue" =~ ^[0-9]+$ ]] || continue
    pr_json="$(gh pr list --repo "$GITHUB_OWNER/$GITHUB_REPO" --state open \
      --head "integra/issue-$issue" --limit 1 \
      --json number,statusCheckRollup 2>/dev/null || true)"
    [[ -n "$pr_json" ]] || continue
    total="$(jq -r '.[0].statusCheckRollup | length // 0' <<<"$pr_json" 2>/dev/null || echo 0)"
    (( total > 0 )) || continue
    incompletos="$(jq -r '[.[0].statusCheckRollup[] | select(.status != "COMPLETED")] | length' <<<"$pr_json" 2>/dev/null || echo 1)"
    (( incompletos == 0 )) || continue
    fallidos="$(jq -r '[.[0].statusCheckRollup[] | select(.conclusion != "SUCCESS" and .conclusion != "NEUTRAL" and .conclusion != "SKIPPED")] | length' <<<"$pr_json" 2>/dev/null || echo 1)"
    if (( fallidos == 0 )); then
      ai_estado_guardar "$issue" ci_success "$intento" "verificaciones de GitHub completadas"
      ai_notificar_pr "$issue" verde
    elif [[ "$estado" != ci_failed ]]; then
      ai_estado_guardar "$issue" ci_failed "$intento" "verificaciones de GitHub fallidas"
      ai_notificar_pr "$issue" rojo
    fi
  done
}

if ai_pausado; then
  echo "Procesador pausado."
  exit 0
fi

reconciliar_ci
"$REPO_RAIZ/scripts/encolar-siguiente.sh"

# La exclusión global garantiza que estos .running pertenecen a una ejecución
# interrumpida. Se recuperan de forma conservadora y conservando el intento.
shopt -s nullglob
for running in "$QUEUE"/issue-*.running; do
  nombre="$(basename "$running")"
  issue="${nombre#issue-}"; issue="${issue%.running}"
  [[ "$issue" =~ ^[0-9]+$ ]] || {
    mv -- "$running" "$QUEUE/fallidas/${nombre}.invalida"
    continue
  }
  pending="$QUEUE/issue-${issue}.pending"
  if [[ ! -e "$pending" ]]; then
    mv -- "$running" "$pending"
    ai_evento "$issue" recovered "solicitud recuperada tras interrupción"
  fi
done

# Una invocación procesa como máximo un issue: evita monopolizar el servicio y
# permite que el timer vuelva a evaluar pausa y recuperación entre tareas.
solicitudes=("$QUEUE"/issue-*.pending)
(( ${#solicitudes[@]} > 0 )) || { echo "Solicitudes procesadas: 0"; exit 0; }
mapfile -t solicitudes < <(printf '%s\n' "${solicitudes[@]}" | sort -V)
solicitud=""
ahora="$(date +%s)"
for candidata in "${solicitudes[@]}"; do
  candidato="$(basename "$candidata")"
  candidato="${candidato#issue-}"; candidato="${candidato%.pending}"
  retry_at="$QUEUE/.issue-${candidato}.retry-at"
  disponible=0
  [[ -f "$retry_at" ]] && read -r disponible < "$retry_at"
  [[ "$disponible" =~ ^[0-9]+$ ]] || disponible=0
  if (( disponible <= ahora )); then
    solicitud="$candidata"
    break
  fi
done
[[ -n "$solicitud" ]] || { echo "Solicitudes pendientes en espera de reintento."; exit 0; }
issue="$(<"$solicitud")"
[[ "$issue" =~ ^[0-9]+$ ]] || {
  mv -- "$solicitud" "$QUEUE/fallidas/$(basename "$solicitud").invalida"
  echo "Solicitud inválida apartada." >&2
  exit 0
}

intentos_file="$QUEUE/.issue-${issue}.attempts"
intentos=0
[[ -f "$intentos_file" ]] && read -r intentos < "$intentos_file"
[[ "$intentos" =~ ^[0-9]+$ ]] || intentos=0
((intentos+=1))
tmp="$intentos_file.$$"; printf '%s\n' "$intentos" > "$tmp"; mv -f -- "$tmp" "$intentos_file"
running="$QUEUE/issue-${issue}.running"
mv -- "$solicitud" "$running"
ai_estado_guardar "$issue" queued "$intentos" "intento preparado"

if AI_ATTEMPT="$intentos" "$REPO_RAIZ/scripts/ejecutar-issue.sh" "$issue"; then
  mv -- "$running" "$QUEUE/completadas/issue-${issue}.done"
  rm -f -- "$intentos_file" "$QUEUE/.issue-${issue}.retry-at"
  echo "Issue #$issue procesado."
  exit 0
else
  rc=$?
fi
if (( intentos <= MAX_RETRIES )); then
  espera=$((RETRY_DELAY * intentos))
  retry_tmp="$QUEUE/.issue-${issue}.retry-at.$$"
  printf '%s\n' "$(( $(date +%s) + espera ))" > "$retry_tmp"
  mv -f -- "$retry_tmp" "$QUEUE/.issue-${issue}.retry-at"
  mv -- "$running" "$QUEUE/issue-${issue}.pending"
  ai_estado_guardar "$issue" retrying "$intentos" "reintento en ${espera}s tras código $rc"
  echo "Issue #$issue reintentará ($intentos/$((MAX_RETRIES + 1)))." >&2
  exit 0
fi

printf '%s\n' "$rc" > "$QUEUE/fallidas/issue-${issue}.exit"
mv -- "$running" "$QUEUE/fallidas/issue-${issue}.failed"
rm -f -- "$intentos_file" "$QUEUE/.issue-${issue}.retry-at"
ai_estado_guardar "$issue" failed "$intentos" "reintentos agotados; código $rc"
echo "Issue #$issue falló tras $intentos intentos." >&2
exit 0
