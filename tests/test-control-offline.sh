#!/usr/bin/env bash
set -euo pipefail

TEST_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$TEST_ROOT/.." && pwd)"
source "$TEST_ROOT/helpers/assertions.sh"
source "$TEST_ROOT/helpers/fixtures.sh"
trap limpiar_fixture EXIT
crear_fixture

CONTROL="$FIXTURE/control-app"
mkdir -p "$CONTROL/scripts" "$AI_QUEUE_DIR/control" "$AI_QUEUE_DIR/fallidas"
mkdir -p "$CONTROL/scripts/lib"
cp "$REPO_ROOT/scripts/procesar-control.sh" "$CONTROL/scripts/"
cp "$REPO_ROOT/scripts/lib/estado.sh" "$REPO_ROOT/scripts/lib/github-app.sh" "$REPO_ROOT/scripts/lib/secretos.sh" "$CONTROL/scripts/lib/"
cat >"$CONTROL/scripts/reportar.sh" <<'EOF'
#!/usr/bin/env bash
printf '%s|%s\n' "${TELEGRAM_DESTINO_CHAT_ID:-}" "$1" >>"${FAKE_LOG_DIR:?}/telegram.messages"
EOF
cat >"$CONTROL/scripts/solicitar-issue.sh" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$1" >"${AI_QUEUE_DIR:?}/issue-$1.pending"
EOF
chmod +x "$CONTROL/scripts/"*.sh
export TELEGRAM_ALLOWED_CHAT_IDS=123 GITHUB_OWNER=owner GITHUB_REPO=repo APPROVAL_TTL_MINUTES=10

encolar_control() {
  local accion="$1" valor="${2:-}" id="${3:-$accion-$RANDOM}"
  jq -cn --arg id "$id" --arg accion "$accion" --arg valor "$valor" \
    '{version:1,id:$id,accion:$accion,valor:$valor,actor:"123",creado:"2026-08-07T00:00:00Z"}' \
    >"$AI_QUEUE_DIR/control/$id.pending"
}

procesar() { "$CONTROL/scripts/procesar-control.sh" >/dev/null; }

echo "Caso: una aprobación exige checks verdes y crea nonce ligado a SHA"
encolar_control aprobar 17 aprobar-verde
procesar
NONCE=aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa
APROBACION="$AI_STATE_DIR/aprobaciones/$NONCE.json"
afirmar_archivo "$APROBACION"
afirmar_igual "$(jq -r .pr "$APROBACION")" 17
afirmar_igual "$(jq -r .sha "$APROBACION")" 0123456789abcdef

echo "Caso: confirmación válida fusiona exactamente una vez"
encolar_control confirmar "$NONCE" confirmar-uno
procesar
afirmar_contiene "$FAKE_LOG_DIR/gh.args" "pr merge 17"
afirmar_contiene "$FAKE_LOG_DIR/gh.args" "--match-head-commit 0123456789abcdef"
afirmar_no_archivo "$APROBACION"
antes="$(grep -c 'pr merge' "$FAKE_LOG_DIR/gh.args")"
encolar_control confirmar "$NONCE" replay
procesar
afirmar_igual "$(grep -c 'pr merge' "$FAKE_LOG_DIR/gh.args")" "$antes"

echo "Caso: nonce vencido no fusiona"
encolar_control aprobar 17 aprobar-vencido
procesar
jq '.expira=0' "$APROBACION" >"$APROBACION.tmp" && mv "$APROBACION.tmp" "$APROBACION"
antes="$(grep -c 'pr merge' "$FAKE_LOG_DIR/gh.args")"
encolar_control confirmar "$NONCE" confirmar-vencido
procesar
afirmar_igual "$(grep -c 'pr merge' "$FAKE_LOG_DIR/gh.args")" "$antes"

echo "Caso: cambio de SHA invalida aprobación"
encolar_control aprobar 17 aprobar-sha
procesar
export FAKE_PR_SHA=ffffffffffffffff
encolar_control confirmar "$NONCE" confirmar-sha
procesar
afirmar_igual "$(grep -c 'pr merge' "$FAKE_LOG_DIR/gh.args")" "$antes"
unset FAKE_PR_SHA

echo "Caso: CI fallida impide incluso crear la confirmación"
export FAKE_CI_CONCLUSION=FAILURE
encolar_control aprobar 17 aprobar-rojo
procesar
afirmar_no_archivo "$APROBACION"
afirmar_no_contiene "$FAKE_LOG_DIR/gh.args" "--admin"

echo "Caso: ausencia de checks también bloquea aprobación"
unset FAKE_CI_CONCLUSION
export FAKE_CI_EMPTY=1
encolar_control aprobar 17 aprobar-sin-checks
procesar
afirmar_no_archivo "$APROBACION"

echo "Caso: aprobar-todo crea un nonce ligado al lote ordenado de PR y SHA"
unset FAKE_CI_EMPTY
export FAKE_PR_LIST_JSON='[
 {"number":19,"url":"https://example.invalid/pull/19","state":"OPEN","isDraft":true,"baseRefName":"main","headRefName":"integra/issue-4","headRefOid":"sha19","mergeStateStatus":"BLOCKED","statusCheckRollup":[{"status":"COMPLETED","conclusion":"SUCCESS"}]},
 {"number":18,"url":"https://example.invalid/pull/18","state":"OPEN","isDraft":false,"baseRefName":"main","headRefName":"integra/issue-3","headRefOid":"sha18","mergeStateStatus":"CLEAN","statusCheckRollup":[{"status":"COMPLETED","conclusion":"SUCCESS"}]},
 {"number":20,"url":"https://example.invalid/pull/20","state":"OPEN","isDraft":false,"baseRefName":"main","headRefName":"otra-rama","headRefOid":"sha20","mergeStateStatus":"CLEAN","statusCheckRollup":[{"status":"COMPLETED","conclusion":"SUCCESS"}]}
]'
encolar_control aprobar-todo '' aprobar-lote
procesar
NONCE=aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa
APROBACION="$AI_STATE_DIR/aprobaciones/$NONCE.json"
afirmar_archivo "$APROBACION"
afirmar_igual "$(jq -r .tipo "$APROBACION")" lote
afirmar_igual "$(jq -r '[.prs[].pr] | join(",")' "$APROBACION")" 18,19
afirmar_igual "$(jq -r '[.prs[].sha] | join(",")' "$APROBACION")" sha18,sha19

echo "Caso: confirmar lote revalida y fusiona secuencialmente"
export FAKE_PR_SHA_BY_NUMBER='{"18":"sha18","19":"sha19"}'
encolar_control confirmar "$NONCE" confirmar-lote
procesar
afirmar_contiene "$FAKE_LOG_DIR/gh.args" "pr merge 18"
afirmar_contiene "$FAKE_LOG_DIR/gh.args" "pr merge 19"
afirmar_no_contiene "$FAKE_LOG_DIR/gh.args" "pr merge 20"
afirmar_no_contiene "$FAKE_LOG_DIR/gh.args" "--admin"

echo "Caso: el lote se detiene al primer SHA cambiado"
encolar_control aprobar-todo '' aprobar-lote-cambio
procesar
export FAKE_PR_SHA_BY_NUMBER='{"18":"sha-cambiado","19":"sha19"}'
antes_19="$(grep -c 'pr merge 19' "$FAKE_LOG_DIR/gh.args")"
encolar_control confirmar "$NONCE" confirmar-lote-cambio
procesar
afirmar_archivo "$AI_QUEUE_DIR/control/fallidas/confirmar-lote-cambio.failed"
afirmar_igual "$(<"$AI_QUEUE_DIR/control/fallidas/confirmar-lote-cambio.exit")" 1
afirmar_igual "$(grep -c 'pr merge 19' "$FAKE_LOG_DIR/gh.args")" "$antes_19"

echo "Caso: un check rojo impide crear autorización para todo el lote"
export FAKE_PR_LIST_JSON='[
 {"number":21,"url":"https://example.invalid/pull/21","state":"OPEN","isDraft":false,"baseRefName":"main","headRefName":"integra/issue-5","headRefOid":"sha21","mergeStateStatus":"CLEAN","statusCheckRollup":[{"status":"COMPLETED","conclusion":"FAILURE"}]}
]'
encolar_control aprobar-todo '' aprobar-lote-rojo
procesar
afirmar_no_archivo "$APROBACION"

echo "Pruebas offline de control y aprobación superadas."
