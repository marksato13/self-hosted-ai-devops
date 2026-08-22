#!/usr/bin/env bash
set -euo pipefail

TEST_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$TEST_ROOT/.." && pwd)"
source "$TEST_ROOT/helpers/assertions.sh"
source "$TEST_ROOT/helpers/fixtures.sh"
trap limpiar_fixture EXIT
crear_fixture

APP="$FIXTURE/app"
mkdir -p "$APP/scripts/lib" "$APP/secrets"
cp "$REPO_ROOT/scripts/reportar.sh" "$APP/scripts/"
cp "$REPO_ROOT/scripts/lib/secretos.sh" "$APP/scripts/lib/"
git -C "$APP" init -q
printf '%s\n' \
  'TELEGRAM_ALLOWED_CHAT_IDS=123' \
  'WHATSAPP_MODO=off' >"$APP/.env"
chmod 600 "$APP/.env"
printf '%s\n' 'TOKEN-SECRETO' >"$APP/secrets/telegram_bot_token"
chmod 600 "$APP/secrets/telegram_bot_token"

reportar_desde_app() {
  (cd "$APP" && ENV_FILE="$APP/.env" AI_SECRETS_DIR="$APP/secrets" "$APP/scripts/reportar.sh" "$@")
}

echo "Caso: Telegram 401 se informa como fallo sin filtrar el token"
export FAKE_HTTP_STATUS=401
ejecutar_rc "$FIXTURE/salida-401" reportar_desde_app "prueba"
afirmar_igual "$RC" 1
afirmar_no_contiene "$FIXTURE/salida-401" "TOKEN-SECRETO"
afirmar_no_contiene "$FAKE_LOG_DIR/curl.calls" "TOKEN-SECRETO"

echo "Caso: Telegram 429 se informa como fallo acotado"
export FAKE_HTTP_STATUS=429
ejecutar_rc "$FIXTURE/salida-429" reportar_desde_app "prueba"
afirmar_igual "$RC" 1
afirmar_igual "$(wc -l < "$FAKE_LOG_DIR/curl.calls")" 2

echo "Caso: no permite notificar a un chat fuera de la allowlist"
export FAKE_HTTP_STATUS=200 TELEGRAM_DESTINO_CHAT_ID=999
ejecutar_rc "$FIXTURE/salida-chat" reportar_desde_app "prueba"
afirmar_igual "$RC" 1
afirmar_igual "$(wc -l < "$FAKE_LOG_DIR/curl.calls")" 2

echo "Pruebas offline del notificador superadas."
