#!/usr/bin/env bash
set -euo pipefail

TEST_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$TEST_ROOT/.." && pwd)"
source "$TEST_ROOT/helpers/assertions.sh"
source "$TEST_ROOT/helpers/fixtures.sh"
trap limpiar_fixture EXIT
crear_fixture

RUNNER="$FIXTURE/runner"
mkdir -p "$RUNNER/scripts/lib"
cp "$REPO_ROOT/scripts/lib/estado.sh" "$RUNNER/scripts/lib/"

cat >"$RUNNER/scripts/reportar.sh" <<'EOF'
#!/usr/bin/env bash
set -eu
printf '%s\n' "$1" >>"${FAKE_LOG_DIR:?}/reportes.calls"
exit "${FAKE_REPORT_RC:-0}"
EOF
chmod +x "$RUNNER/scripts/reportar.sh"

# shellcheck source=scripts/lib/estado.sh
source "$RUNNER/scripts/lib/estado.sh"

echo "Caso: informa las etapas sin incluir detalles arbitrarios"
ai_estado_preparar
ai_estado_guardar 21 planning 1 'TOKEN-QUE-NO-DEBE-SALIR'
ai_estado_guardar 21 running 1 'respuesta completa del proveedor'
ai_notificar_agentes 21 'backend,tests,docs'
ai_estado_guardar 21 waiting_approval 1 'PR con datos internos'
afirmar_igual "$(wc -l < "$FAKE_LOG_DIR/reportes.calls")" 4
afirmar_contiene "$FAKE_LOG_DIR/reportes.calls" 'Issue #21'
afirmar_contiene "$FAKE_LOG_DIR/reportes.calls" 'backend, tests, docs'
afirmar_no_contiene "$FAKE_LOG_DIR/reportes.calls" 'TOKEN-QUE-NO-DEBE-SALIR'
afirmar_no_contiene "$FAKE_LOG_DIR/reportes.calls" 'respuesta completa'

echo "Caso: un fallo del notificador no altera el estado durable"
export FAKE_REPORT_RC=1
ai_estado_guardar 22 retrying 2 'fallo sensible del proveedor'
afirmar_igual "$(jq -r .estado "$AI_STATE_DIR/issues/22/state.json")" retrying
afirmar_contiene "$AI_STATE_DIR/issues/22/events.jsonl" 'notification_failed'
afirmar_no_contiene "$FAKE_LOG_DIR/reportes.calls" 'fallo sensible'

echo "Caso: contempla CI, aprobación, fallo y merge"
unset FAKE_REPORT_RC
for estado in ci_success approved failed completed; do
  ai_estado_guardar 23 "$estado" 1 'detalle no publicable'
done
afirmar_contiene "$FAKE_LOG_DIR/reportes.calls" 'CI aprobada'
afirmar_contiene "$FAKE_LOG_DIR/reportes.calls" 'aprobación registrada'
afirmar_contiene "$FAKE_LOG_DIR/reportes.calls" 'detenido tras agotar'
afirmar_contiene "$FAKE_LOG_DIR/reportes.calls" 'PR fusionado'

echo "Pruebas offline de reportes automáticos superadas."
