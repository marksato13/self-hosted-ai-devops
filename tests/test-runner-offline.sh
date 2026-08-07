#!/usr/bin/env bash
set -euo pipefail

TEST_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$TEST_ROOT/.." && pwd)"
source "$TEST_ROOT/helpers/assertions.sh"
source "$TEST_ROOT/helpers/fixtures.sh"
trap limpiar_fixture EXIT
crear_fixture

crear_runner_aislado() {
  RUNNER="$FIXTURE/runner"
  mkdir -p "$RUNNER/scripts/lib"
  cp "$REPO_ROOT/scripts/procesar-cola.sh" "$REPO_ROOT/scripts/control-runner.sh" \
    "$REPO_ROOT/scripts/encolar-siguiente.sh" "$RUNNER/scripts/"
  cp "$REPO_ROOT/scripts/lib/estado.sh" "$RUNNER/scripts/lib/"
cat >"$RUNNER/scripts/ejecutar-issue.sh" <<'EOF'
#!/usr/bin/env bash
set -eu
printf '%s:%s\n' "$1" "${AI_ATTEMPT:-}" >>"${FAKE_LOG_DIR:?}/executor.calls"
fallas=${FAKE_EXECUTOR_FAILURES:-0}
(( ${AI_ATTEMPT:-1} <= fallas )) && exit 70
source "$(dirname "$0")/lib/estado.sh"
ai_estado_guardar "$1" waiting_approval "${AI_ATTEMPT:-1}" "PR borrador"
EOF
  chmod +x "$RUNNER/scripts/"*.sh
}

crear_runner_aislado

echo "Caso: pausa y reanudación persistentes"
"$RUNNER/scripts/control-runner.sh" pausar >/dev/null
afirmar_archivo "$AI_STATE_DIR/PAUSED"
afirmar_igual "$("$RUNNER/scripts/control-runner.sh" estado)" pausado
printf '8\n' >"$AI_QUEUE_DIR/issue-8.pending"
"$RUNNER/scripts/procesar-cola.sh" >"$FIXTURE/salida"
afirmar_archivo "$AI_QUEUE_DIR/issue-8.pending"
afirmar_no_archivo "$FAKE_LOG_DIR/executor.calls"
"$RUNNER/scripts/control-runner.sh" reanudar >/dev/null
afirmar_igual "$("$RUNNER/scripts/control-runner.sh" estado)" activo

echo "Caso: éxito deja estado terminal y procesa una vez"
"$RUNNER/scripts/procesar-cola.sh" >/dev/null
afirmar_archivo "$AI_QUEUE_DIR/completadas/issue-8.done"
afirmar_contiene "$FAKE_LOG_DIR/executor.calls" "8:1"
afirmar_igual "$(jq -r .estado "$AI_STATE_DIR/issues/8/state.json")" waiting_approval

echo "Caso: recupera running huérfano"
printf '9\n' >"$AI_QUEUE_DIR/issue-9.running"
"$RUNNER/scripts/procesar-cola.sh" >/dev/null
afirmar_archivo "$AI_QUEUE_DIR/completadas/issue-9.done"
afirmar_contiene "$AI_STATE_DIR/issues/9/events.jsonl" recovered

echo "Caso: reintentos acotados y contador persistente"
export MAX_RETRIES_PER_TASK=2 AI_RETRY_DELAY_SECONDS=0 FAKE_EXECUTOR_FAILURES=99
printf '10\n' >"$AI_QUEUE_DIR/issue-10.pending"
"$RUNNER/scripts/procesar-cola.sh" >/dev/null 2>&1
afirmar_archivo "$AI_QUEUE_DIR/issue-10.pending"
"$RUNNER/scripts/procesar-cola.sh" >/dev/null 2>&1
afirmar_archivo "$AI_QUEUE_DIR/issue-10.pending"
"$RUNNER/scripts/procesar-cola.sh" >/dev/null 2>&1
afirmar_archivo "$AI_QUEUE_DIR/fallidas/issue-10.failed"
afirmar_igual "$(grep -c '^10:' "$FAKE_LOG_DIR/executor.calls")" 3
afirmar_igual "$(jq -r .estado "$AI_STATE_DIR/issues/10/state.json")" failed

echo "Caso: un fallo transitorio termina sin duplicar ejecución"
export FAKE_EXECUTOR_FAILURES=1
printf '11\n' >"$AI_QUEUE_DIR/issue-11.pending"
"$RUNNER/scripts/procesar-cola.sh" >/dev/null 2>&1
"$RUNNER/scripts/procesar-cola.sh" >/dev/null 2>&1
afirmar_archivo "$AI_QUEUE_DIR/completadas/issue-11.done"
afirmar_igual "$(grep -c '^11:' "$FAKE_LOG_DIR/executor.calls")" 2

echo "Caso: reconcilia una CI terminada y registra el estado"
source "$RUNNER/scripts/lib/estado.sh"
ai_estado_guardar 24 waiting_approval 1 'PR borrador'
export GITHUB_OWNER=marksato13 GITHUB_REPO=ninjasec-platform
export FAKE_PR_LIST_JSON='[{"number":24,"statusCheckRollup":[{"status":"COMPLETED","conclusion":"SUCCESS"}]}]'
"$RUNNER/scripts/procesar-cola.sh" >/dev/null
afirmar_igual "$(jq -r .estado "$AI_STATE_DIR/issues/24/state.json")" ci_success

echo "Pruebas offline del runner superadas."
