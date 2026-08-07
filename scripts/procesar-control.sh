#!/usr/bin/env bash
# Procesa sobres creados por control-flota.sh. Corre en el host, no en OpenClaw.
set -euo pipefail

REPO_RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="${ENV_FILE:-$REPO_RAIZ/.env}"
set -a
[[ -f "$ENV_FILE" ]] && source "$ENV_FILE"
set +a
# shellcheck source=scripts/lib/estado.sh
source "$REPO_RAIZ/scripts/lib/estado.sh"

command -v jq >/dev/null || { echo "Falta jq." >&2; exit 69; }
command -v gh >/dev/null || { echo "Falta gh." >&2; exit 69; }
command -v openssl >/dev/null || { echo "Falta openssl." >&2; exit 69; }

COLA="${AI_QUEUE_DIR:-$HOME/.local/state/ai-devops/queue}"
CONTROL="$COLA/control"
ESTADO="${AI_STATE_DIR:-$HOME/.local/state/ai-devops}"
APROBACIONES="$ESTADO/aprobaciones"
OWNER="${GITHUB_OWNER:?falta GITHUB_OWNER}"
REPO="${GITHUB_REPO:?falta GITHUB_REPO}"
TTL="${APPROVAL_TTL_MINUTES:-10}"
[[ "$TTL" =~ ^[1-9][0-9]{0,2}$ ]] || { echo "APPROVAL_TTL_MINUTES inválido." >&2; exit 65; }
mkdir -p "$CONTROL/completadas" "$CONTROL/fallidas" "$APROBACIONES"
chmod 700 "$CONTROL" "$CONTROL/completadas" "$CONTROL/fallidas" "$APROBACIONES"
exec 9>"$CONTROL/.procesador.lock"
flock -n 9 || { echo "Ya hay otro procesador de control activo." >&2; exit 75; }

notificar() {
  local actor="$1" mensaje="$2"
  TELEGRAM_DESTINO_CHAT_ID="$actor" "$REPO_RAIZ/scripts/reportar.sh" "$mensaje"
}

pr_json() {
  gh pr view "$1" --repo "$OWNER/$REPO" \
    --json number,url,state,isDraft,baseRefName,headRefName,headRefOid,mergeStateStatus,statusCheckRollup
}

validar_pr() {
  local archivo="$1" numero="$2"
  jq -e --argjson numero "$numero" '
    .number == $numero and .state == "OPEN" and .baseRefName == "main" and
    (.headRefName | startswith("integra/issue-")) and
    (.mergeStateStatus == "CLEAN" or (.isDraft == true and .mergeStateStatus == "BLOCKED")) and
    (.statusCheckRollup | length > 0) and
    ([.statusCheckRollup[] |
      ((.status // "COMPLETED") == "COMPLETED") and
      ((.conclusion // "") | IN("SUCCESS", "NEUTRAL", "SKIPPED"))] | all)
  ' "$archivo" >/dev/null
}

estado_flota() {
  local pendientes ejecutando fallidas pausa prs
  pendientes="$(find "$COLA" -maxdepth 1 -name 'issue-*.pending' -printf . 2>/dev/null | wc -c)"
  ejecutando="$(find "$COLA" -maxdepth 1 -name 'issue-*.running' -printf . 2>/dev/null | wc -c)"
  fallidas="$(find "$COLA/fallidas" -maxdepth 1 -name 'issue-*.failed' -printf . 2>/dev/null | wc -c)"
  if ai_pausado; then pausa="sí"; else pausa="no"; fi
  prs="$(gh pr list --repo "$OWNER/$REPO" --state open --limit 10 --json number,url,isDraft \
    --jq 'map("#\(.number)" + (if .isDraft then " (borrador)" else "" end)) | join(", ")' 2>/dev/null || echo "no disponible")"
  printf 'Flota: pausada=%s; pendientes=%s; ejecutando=%s; fallidas=%s; PR abiertos=%s.' \
    "$pausa" "$pendientes" "$ejecutando" "$fallidas" "${prs:-ninguno}"
}

procesar() {
  local sobre="$1" accion valor actor pr tmp nonce exp guardado actual sha head issue
  jq -e '.version == 1 and (.id|type=="string") and (.accion|type=="string") and
    (.valor|type=="string") and (.actor|test("^[0-9]+$")) and (.creado|type=="string")' \
    "$sobre" >/dev/null || return 65
  accion="$(jq -r .accion "$sobre")"; valor="$(jq -r .valor "$sobre")"; actor="$(jq -r .actor "$sobre")"
  case ",$TELEGRAM_ALLOWED_CHAT_IDS," in *",$actor,"*) ;; *) return 77 ;; esac

  case "$accion" in
    ayuda)
      notificar "$actor" 'Comandos: estado, siguiente, issue N, aprobar PR, confirmar CÓDIGO, rechazar PR, detener, reanudar y errores [N]. No existe shell libre.'
      ;;
    estado) notificar "$actor" "$(estado_flota)" ;;
    errores)
      if [[ -n "$valor" ]]; then
        if [[ -f "$COLA/fallidas/issue-${valor}.exit" ]]; then
          notificar "$actor" "Issue #$valor falló (código $(<"$COLA/fallidas/issue-${valor}.exit")). Revisa el PR o solicita intervención; no se envían logs por Telegram."
        else
          notificar "$actor" "No hay un fallo registrado para el issue #$valor."
        fi
      else
        tmp="$(find "$COLA/fallidas" -maxdepth 1 -name 'issue-*.failed' -printf '%f\n' 2>/dev/null | sort -V | tail -n 10 | paste -sd, -)"
        notificar "$actor" "Issues fallidos recientes: ${tmp:-ninguno}. Los logs permanecen en la VM."
      fi
      ;;
    issue)
      ! ai_pausado || { notificar "$actor" "La flota está pausada; usa reanudar antes de solicitar el issue #$valor."; return 0; }
      if AI_QUEUE_DIR="$COLA" "$REPO_RAIZ/scripts/solicitar-issue.sh" "$valor"; then
        notificar "$actor" "Issue #$valor encolado."
      else
        notificar "$actor" "No se pudo encolar el issue #$valor; puede estar ya pendiente o activo."
      fi
      ;;
    siguiente)
      ! ai_pausado || { notificar "$actor" 'La flota está pausada; usa reanudar primero.'; return 0; }
      valor="$(gh issue list --repo "$OWNER/$REPO" --state open --label 'agente:lista' --limit 100 \
        --json number,labels --jq '[.[] | select([.labels[].name] | index("bloqueada") | not)] | sort_by(.number) | .[0].number // empty')"
      if [[ -z "$valor" ]]; then
        notificar "$actor" 'No hay issues abiertos con la etiqueta agente:lista y sin bloqueos.'
      elif AI_QUEUE_DIR="$COLA" "$REPO_RAIZ/scripts/solicitar-issue.sh" "$valor"; then
        notificar "$actor" "Siguiente issue elegible encolado: #$valor."
      else
        notificar "$actor" "El issue #$valor ya estaba pendiente o activo."
      fi
      ;;
    detener)
      ai_pausar
      notificar "$actor" 'Flota pausada: no se admitirán tareas nuevas. La tarea activa, si existe, terminará de forma controlada.'
      ;;
    reanudar)
      ai_reanudar
      notificar "$actor" 'Flota reanudada.'
      ;;
    aprobar)
      tmp="$(mktemp)"
      pr_json "$valor" >"$tmp"
      if ! validar_pr "$tmp" "$valor"; then
        notificar "$actor" "PR #$valor no es aprobable: debe estar abierto, apuntar a main desde integra/issue-*, sin conflictos y con todos los checks terminados correctamente."
        return 0
      fi
      nonce="$(openssl rand -hex 16)"; exp="$(( $(date +%s) + TTL * 60 ))"
      jq -n --arg nonce "$nonce" --arg actor "$actor" --argjson pr "$valor" \
        --arg sha "$(jq -r .headRefOid "$tmp")" --argjson exp "$exp" \
        '{version:1,nonce:$nonce,actor:$actor,pr:$pr,sha:$sha,expira:$exp}' >"$APROBACIONES/$nonce.json"
      chmod 600 "$APROBACIONES/$nonce.json"
      notificar "$actor" "PR #$valor validado en $(jq -r '.headRefOid[0:12]' "$tmp"). Para autorizar el merge explícitamente responde: confirmar $nonce. El código vence en $TTL minutos y funciona una sola vez."
      rm -f -- "$tmp"
      ;;
    confirmar)
      guardado="$APROBACIONES/$valor.json"
      [[ -f "$guardado" ]] || { notificar "$actor" 'Código desconocido, vencido o ya utilizado.'; return 0; }
      exec 8>"$guardado.lock"; flock -n 8 || { notificar "$actor" 'Esa confirmación ya está siendo procesada.'; return 0; }
      mv -- "$guardado" "$guardado.usado"
      [[ "$(jq -r .actor "$guardado.usado")" == "$actor" ]] || { rm -f -- "$guardado.usado"; notificar "$actor" 'El código pertenece a otro operador.'; return 0; }
      (( $(date +%s) <= $(jq -r .expira "$guardado.usado") )) || { rm -f -- "$guardado.usado"; notificar "$actor" 'El código venció; solicita una aprobación nueva.'; return 0; }
      pr="$(jq -r .pr "$guardado.usado")"; sha="$(jq -r .sha "$guardado.usado")"
      tmp="$(mktemp)"; pr_json "$pr" >"$tmp"
      if ! validar_pr "$tmp" "$pr" || [[ "$(jq -r .headRefOid "$tmp")" != "$sha" ]]; then
        rm -f -- "$tmp" "$guardado.usado"
        notificar "$actor" "PR #$pr cambió o dejó de cumplir las validaciones; no se fusionó."
        return 0
      fi
      head="$(jq -r .headRefName "$tmp")"
      issue="${head#integra/issue-}"
      if [[ "$(jq -r .isDraft "$tmp")" == true ]]; then gh pr ready "$pr" --repo "$OWNER/$REPO" >/dev/null; fi
      if gh pr merge "$pr" --repo "$OWNER/$REPO" --merge --delete-branch \
        --match-head-commit "$sha"; then
        ai_estado_guardar "$issue" completed 0 "PR #$pr fusionado con confirmación humana"
        if [[ -d "${AI_TARGET_REPO_DIR:-}" ]]; then
          (cd "$AI_TARGET_REPO_DIR" && "$REPO_RAIZ/scripts/limpiar-worktrees.sh" "$issue") >/dev/null 2>&1 || true
        fi
        notificar "$actor" "PR #$pr fusionado después de la confirmación humana explícita."
      else
        notificar "$actor" "GitHub rechazó el merge del PR #$pr; no se forzó ni se usó bypass."
        rm -f -- "$tmp" "$guardado.usado"
        return 1
      fi
      rm -f -- "$tmp" "$guardado.usado"
      ;;
    rechazar)
      tmp="$(mktemp)"; pr_json "$valor" >"$tmp"
      if jq -e --argjson n "$valor" '.number==$n and .state=="OPEN" and .baseRefName=="main" and (.headRefName|startswith("integra/issue-"))' "$tmp" >/dev/null; then
        gh pr close "$valor" --repo "$OWNER/$REPO" --comment 'Cerrado por decisión humana explícita desde el canal de control.' >/dev/null
        notificar "$actor" "PR #$valor rechazado y cerrado."
      else
        notificar "$actor" "PR #$valor no corresponde a una integración abierta de esta flota."
      fi
      rm -f -- "$tmp"
      ;;
    *) return 64 ;;
  esac
}

shopt -s nullglob
for sobre in "$CONTROL"/*.pending; do
  nombre="$(basename "$sobre" .pending)"
  if procesar "$sobre"; then
    mv -- "$sobre" "$CONTROL/completadas/$nombre.done"
  else
    rc=$?
    printf '%s\n' "$rc" >"$CONTROL/fallidas/$nombre.exit"
    mv -- "$sobre" "$CONTROL/fallidas/$nombre.failed"
  fi
done
