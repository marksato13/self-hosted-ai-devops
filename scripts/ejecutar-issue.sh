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

# Algunas VMs (incluido este host) deshabilitan user namespaces y bubblewrap no
# puede crear el sandbox aunque Codex esté instalado correctamente. Conservamos
# el sandbox cuando es viable; en ese entorno concreto usamos el modo completo
# sobre el repositorio objetivo, que ya está aislado por el servicio systemd.
codex_sandbox() {
  local solicitado="$1"
  if [[ -n "${CODEX_SANDBOX_MODE:-}" ]]; then
    printf '%s' "$CODEX_SANDBOX_MODE"
  elif unshare -Ur true >/dev/null 2>&1; then
    printf '%s' "$solicitado"
  else
    echo "Aviso: user namespaces no disponibles; Codex usará danger-full-access en este host." >&2
    printf '%s' danger-full-access
  fi
}

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
  # No explorar archivos: cada llamada a herramienta del planificador suma
  # riesgo de chocar con el bug de tool_call_id duplicado de las rutas
  # oc/* de OmniRoute en sesiones largas (ADR-024, confirmado 2026-08-08:
  # cero llamadas a herramientas evita el bug de forma consistente).
  echo "No modifiques archivos. No leas, explores ni listes ningún otro archivo del repositorio: usá exclusivamente el texto de este issue."
  echo "Devuelve únicamente JSON válido, sin markdown, con esta forma exacta:"
  echo '{"resumen":"...","subtareas":[{"agente":"backend|tests|docs","descripcion":"...","criterio_aceptacion":"..."}]}'
  echo "Usa como máximo una subtarea por agente y únicamente esos tres valores de agente."
  jq . "$ESTADO/issue.json"
} > "$PROMPT_PLAN"

# Orden pensado para no depender de Codex/ChatGPT: rutas gratuitas de
# OmniRoute primero, Codex solo como último recurso si hay cuota. Ver
# docs/decisiones.md — ADR-024.
PLANNER_MODEL="${CODEX_PLANNER_MODEL:-oc/big-pickle}"
PLANNER_MODELS=("$PLANNER_MODEL" "${CODEX_PLANNER_FALLBACK_MODEL:-oc/deepseek-v4-flash-free}" "${CODEX_PLANNER_LAST_RESORT_MODEL:-cx/gpt-5.6-sol}")
planner_ok=0
planner_rate_limited=0
for modelo in "${PLANNER_MODELS[@]}"; do
  [[ "$modelo" =~ ^[a-z0-9/:.-]+$ ]] || continue
  planner_log="$ESTADO/planner-${modelo//[^a-zA-Z0-9]/_}.log"
  # Sin --output-schema: las rutas gratuitas de OmniRoute devuelven
  # "response_format type is unavailable now" con salida JSON estructurada
  # (confirmado 2026-08-08, ver ADR-024). El prompt ya pide JSON estricto y
  # se valida más abajo; si el modelo lo envuelve en markdown, se limpia
  # antes de validar.
  if timeout "$TIMEOUT" codex exec -p planner -m "$modelo" -s "$(codex_sandbox read-only)" -C "$TARGET_REPO" \
      -o "$ESTADO/plan.json" - < "$PROMPT_PLAN" >"$planner_log" 2>&1; then
    planner_ok=1
    break
  fi
  if ! grep -qE '429|rate.limit|Too Many Requests' "$planner_log"; then
    cat "$planner_log" >&2
    break
  fi
  planner_rate_limited=1
  echo "Planificador saturado con $modelo; probando el siguiente modelo Codex." >&2
done
(( planner_ok == 1 )) || {
  if (( planner_rate_limited == 1 )); then
    echo "Todos los modelos de planificación están temporalmente limitados." >&2
    exit 75
  fi
  echo "El planificador no pudo responder con los modelos configurados." >&2
  exit 1
}
if ! jq -e . "$ESTADO/plan.json" >/dev/null 2>&1; then
  # Sin --output-schema algunos modelos envuelven la respuesta en una
  # cerca de markdown pese a la instrucción; se quita solo si es la
  # primera y/o última línea, nunca en medio del contenido.
  sed -i -e '1{/^```/d}' -e '$ {/^```/d}' "$ESTADO/plan.json"
fi
jq -e . "$ESTADO/plan.json" >/dev/null
jq -e '
  (.resumen | type == "string" and length > 0) and
  (.subtareas | type == "array" and length >= 1 and length <= 3) and
  (all(.subtareas[]; (.agente == "backend" or .agente == "tests" or .agente == "docs") and
    (.descripcion | type == "string" and length > 0) and
    (.criterio_aceptacion | type == "string" and length > 0))) and
  (([.subtareas[].agente] | unique | length) == (.subtareas | length))
' "$ESTADO/plan.json" >/dev/null || {
  echo "El planificador devolvió un plan incompatible con config/plan.schema.json." >&2
  exit 65
}

ai_estado_guardar "$ISSUE" running "$INTENTO" "agentes en ejecución"

mapfile -t AGENTES < <(jq -r '.subtareas[].agente' "$ESTADO/plan.json" | sort -u)
AGENTES_MENSAJE="$(IFS=,; echo "${AGENTES[*]}")"
ai_notificar_agentes "$ISSUE" "$AGENTES_MENSAJE"
(cd "$TARGET_REPO" && "$REPO_RAIZ/scripts/nueva-tarea.sh" "$ISSUE" "${AGENTES[@]}")

AGENT_PARALLELISM="${AI_AGENT_CONCURRENCY:-1}"
[[ "$AGENT_PARALLELISM" =~ ^[1-9][0-9]*$ ]] || AGENT_PARALLELISM=1
pids=()
# Prueba cada modelo de la lista en orden; pasa al siguiente solo si el
# fallo es un límite temporal del proveedor (429). Un fallo real (código,
# pruebas, etc.) corta la lista y se reporta tal cual — no se enmascara
# reintentando con otro modelo.
ejecutar_agente() {
  local agente="$1" perfil="$2" wt="$3"; shift 3
  local modelos=("$@") modelo intento_log motivo_log intento_out rc
  intento_log="$ESTADO/${agente}.log"
  motivo_log="$ESTADO/${agente}.motivo"
  : >"$intento_log"
  rm -f "$motivo_log"
  for modelo in "${modelos[@]}"; do
    [[ "$modelo" =~ ^[a-z0-9/:.-]+$ ]] || continue
    intento_out="$(mktemp)"
    {
      echo "── $agente con $modelo ──"
      timeout "$TIMEOUT" codex exec -p "$perfil" -m "$modelo" -s "$(codex_sandbox workspace-write)" -C "$wt" \
        -o "$ESTADO/resultado-${agente}.txt" - < "$ESTADO/prompt-${agente}.txt"
    } >"$intento_out" 2>&1
    rc=$?
    cat "$intento_out" >>"$intento_log"
    if (( rc == 0 )); then
      rm -f "$intento_out"
      return 0
    fi
    # Solo se compara la salida DE ESTE intento: un 429 de un modelo
    # anterior no debe disfrazar un fallo real del siguiente.
    if ! grep -qE '429|rate.limit|Too Many Requests' "$intento_out"; then
      rm -f "$intento_out"
      echo "real" >"$motivo_log"
      return 1
    fi
    rm -f "$intento_out"
    echo "$agente saturado con $modelo; probando el siguiente modelo." >&2
  done
  echo "proveedor" >"$motivo_log"
  return 1
}
for agente in "${AGENTES[@]}"; do
  perfil="$agente"; [[ "$agente" == tests ]] && perfil=tester
  wt="$(dirname "$TARGET_REPO")/worktrees/issue-${ISSUE}-${agente}"
  jq -r --arg a "$agente" '.subtareas[] | select(.agente == $a) |
    "Implementa esta subtarea y crea un commit en tu rama.\nDescripción: " +
    .descripcion + "\nCriterio de aceptación: " + .criterio_aceptacion' \
    "$ESTADO/plan.json" > "$ESTADO/prompt-${agente}.txt"
  # Mismo orden que el planificador: gratis primero, Codex solo si hay
  # cuota y todo lo demás falló. Ver docs/decisiones.md — ADR-024.
  case "$agente" in
    backend) modelos_agente=("${CODEX_BACKEND_MODEL:-oc/big-pickle}" "${CODEX_BACKEND_FALLBACK_MODEL:-oc/deepseek-v4-flash-free}" "${CODEX_BACKEND_LAST_RESORT_MODEL:-cx/gpt-5.6-sol}") ;;
    tests) modelos_agente=("${CODEX_TESTS_MODEL:-oc/big-pickle}" "${CODEX_TESTS_FALLBACK_MODEL:-oc/deepseek-v4-flash-free}" "${CODEX_TESTS_LAST_RESORT_MODEL:-cx/gpt-5.6-terra}") ;;
    docs) modelos_agente=("${CODEX_DOCS_MODEL:-oc/big-pickle}" "${CODEX_DOCS_FALLBACK_MODEL:-oc/deepseek-v4-flash-free}" "${CODEX_DOCS_LAST_RESORT_MODEL:-cx/gpt-5.5}") ;;
    *) modelos_agente=("${CODEX_AGENT_MODEL:-oc/big-pickle}" "oc/deepseek-v4-flash-free" "cx/gpt-5.6-terra") ;;
  esac
  if (( AGENT_PARALLELISM == 1 )); then
    ejecutar_agente "$agente" "$perfil" "$wt" "${modelos_agente[@]}" || pids+=("failed:$agente")
  else
    ( ejecutar_agente "$agente" "$perfil" "$wt" "${modelos_agente[@]}" ) &
    pids+=("$!")
  fi
done

fallos=0
fallos_proveedor=0
for pid in "${pids[@]}"; do
  if [[ "$pid" == failed:* ]]; then
    ((fallos+=1))
  else
    wait "$pid" || ((fallos+=1))
  fi
done
if (( fallos > 0 )); then
  for agente in "${AGENTES[@]}"; do
    [[ "$(cat "$ESTADO/${agente}.motivo" 2>/dev/null)" == "proveedor" ]] && ((fallos_proveedor+=1)) || true
  done
  if (( fallos_proveedor == fallos )); then
    echo "Los agentes no pudieron iniciar por límite temporal del proveedor." >&2
    exit 75
  fi
  echo "$fallos agentes fallaron." >&2
  exit 70
fi

ai_estado_guardar "$ISSUE" integrating "$INTENTO" "integrando ramas"
(cd "$TARGET_REPO" && "$REPO_RAIZ/scripts/integrar.sh" "$ISSUE")
ai_estado_guardar "$ISSUE" waiting_approval "$INTENTO" "pull request en borrador"
ai_notificar_pr "$ISSUE" abierto
trap - EXIT
