#!/usr/bin/env bash
set -euo pipefail

ISSUE="${1:-}"
[[ "$ISSUE" =~ ^[0-9]+$ ]] || { echo "Uso: $0 <numero-de-issue>" >&2; exit 64; }

REPO_RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="${ENV_FILE:-$REPO_RAIZ/.env}"
set -a
[[ -f "$ENV_FILE" ]] && source "$ENV_FILE"
set +a

# shellcheck source=scripts/lib/estado.sh
source "$REPO_RAIZ/scripts/lib/estado.sh"

command -v codex >/dev/null || { echo "Falta codex." >&2; exit 69; }
command -v gh >/dev/null || { echo "Falta gh." >&2; exit 69; }
command -v jq >/dev/null || { echo "Falta jq." >&2; exit 69; }

OWNER="${GITHUB_OWNER:?falta GITHUB_OWNER}"
REPO="${GITHUB_REPO:?falta GITHUB_REPO}"
TARGET_REPO="${AI_TARGET_REPO_DIR:-$HOME/workspace/$REPO}"
TIMEOUT="${TASK_TIMEOUT_MINUTES:-30}m"
ESTADO="${AI_STATE_DIR:-$HOME/.local/state/ai-devops}/issues/$ISSUE"
mkdir -p "$ESTADO"
INTENTO="${AI_ATTEMPT:-1}"
[[ "$INTENTO" =~ ^[1-9][0-9]*$ ]] || INTENTO=1
ai_estado_preparar
git -C "$TARGET_REPO" rev-parse --show-toplevel >/dev/null 2>&1 || {
  echo "AI_TARGET_REPO_DIR no apunta a un repositorio Git: $TARGET_REPO" >&2
  exit 66
}
exec 9>"$ESTADO/.lock"
flock -n 9 || { echo "El issue #$ISSUE ya está ejecutándose." >&2; exit 75; }

finalizar_estado() {
  local rc=$?
  if [[ $rc -ne 0 ]]; then
    ai_estado_guardar "$ISSUE" failed "$INTENTO" "ejecución terminada con código $rc"
  fi
}
trap finalizar_estado EXIT
ai_estado_guardar "$ISSUE" planning "$INTENTO" "planificando issue"

gh issue view "$ISSUE" --repo "$OWNER/$REPO" \
  --json number,title,body,url,state > "$ESTADO/issue.json"
jq -e '.state == "OPEN"' "$ESTADO/issue.json" >/dev/null || {
  echo "El issue #$ISSUE no está abierto." >&2
  exit 65
}

PROMPT_PLAN="$ESTADO/prompt-plan.txt"
{
  echo "Planifica el issue de GitHub adjunto para tres roles independientes."
  echo "No modifiques archivos. Devuelve únicamente el JSON solicitado."
  jq . "$ESTADO/issue.json"
} > "$PROMPT_PLAN"

timeout "$TIMEOUT" codex exec -p planner -s read-only -C "$TARGET_REPO" \
  --output-schema "$REPO_RAIZ/config/plan.schema.json" \
  -o "$ESTADO/plan.json" - < "$PROMPT_PLAN"
jq -e . "$ESTADO/plan.json" >/dev/null

ai_estado_guardar "$ISSUE" running "$INTENTO" "agentes en ejecución"

mapfile -t AGENTES < <(jq -r '.subtareas[].agente' "$ESTADO/plan.json" | sort -u)
AGENTES_MENSAJE="$(IFS=,; echo "${AGENTES[*]}")"
ai_notificar_agentes "$ISSUE" "$AGENTES_MENSAJE"
(cd "$TARGET_REPO" && "$REPO_RAIZ/scripts/nueva-tarea.sh" "$ISSUE" "${AGENTES[@]}")

pids=()
for agente in "${AGENTES[@]}"; do
  perfil="$agente"; [[ "$agente" == tests ]] && perfil=tester
  wt="$(dirname "$TARGET_REPO")/worktrees/issue-${ISSUE}-${agente}"
  jq -r --arg a "$agente" '.subtareas[] | select(.agente == $a) |
    "Implementa esta subtarea y crea un commit en tu rama.\nDescripción: " +
    .descripcion + "\nCriterio de aceptación: " + .criterio_aceptacion' \
    "$ESTADO/plan.json" > "$ESTADO/prompt-${agente}.txt"
  (
    timeout "$TIMEOUT" codex exec -p "$perfil" -s workspace-write -C "$wt" \
      -o "$ESTADO/resultado-${agente}.txt" - < "$ESTADO/prompt-${agente}.txt"
  ) >"$ESTADO/${agente}.log" 2>&1 &
  pids+=("$!")
done

fallos=0
for pid in "${pids[@]}"; do
  wait "$pid" || ((fallos+=1))
done
[[ $fallos -eq 0 ]] || { echo "$fallos agentes fallaron." >&2; exit 70; }

ai_estado_guardar "$ISSUE" integrating "$INTENTO" "integrando ramas"
(cd "$TARGET_REPO" && "$REPO_RAIZ/scripts/integrar.sh" "$ISSUE")
ai_estado_guardar "$ISSUE" waiting_approval "$INTENTO" "pull request en borrador"
ai_notificar_pr "$ISSUE" abierto
trap - EXIT
