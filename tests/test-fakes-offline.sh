#!/usr/bin/env bash
set -euo pipefail

TEST_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$TEST_ROOT/helpers/assertions.sh"
source "$TEST_ROOT/helpers/fixtures.sh"
trap limpiar_fixture EXIT
crear_fixture

echo "Caso: GitHub se simula sin red"
FAKE_GH_ISSUE_STATE=CLOSED gh issue view 9 >"$FIXTURE/issue.json"
afirmar_contiene "$FIXTURE/issue.json" '"state":"CLOSED"'
FAKE_CI_RC=1 ejecutar_rc "$FIXTURE/salida" gh pr checks 17
afirmar_igual "$RC" 1

echo "Caso: Codex permite simular reintentos"
export FAKE_CODEX_FAILURES=1
ejecutar_rc "$FIXTURE/salida" codex exec -o "$FIXTURE/plan.json"
afirmar_igual "$RC" 70
ejecutar_rc "$FIXTURE/salida" codex exec -o "$FIXTURE/plan.json"
afirmar_igual "$RC" 0
afirmar_archivo "$FIXTURE/plan.json"

echo "Caso: Telegram permite simular 401 y 429 sin registrar el token"
export FAKE_HTTP_STATUS=401
ejecutar_rc "$FIXTURE/salida" curl --fail-with-body -sS -o "$FIXTURE/respuesta" "https://api.telegram.org/botTOKEN-SECRETO/sendMessage"
afirmar_igual "$RC" 22
afirmar_no_contiene "$FAKE_LOG_DIR/curl.calls" "TOKEN-SECRETO"
export FAKE_HTTP_STATUS=429
ejecutar_rc "$FIXTURE/salida" curl --fail-with-body -sS -o "$FIXTURE/respuesta" "https://api.telegram.org/botTOKEN-SECRETO/sendMessage"
afirmar_igual "$RC" 22
afirmar_igual "$(wc -l < "$FAKE_LOG_DIR/curl.calls")" 2

echo "Dobles offline validados."
