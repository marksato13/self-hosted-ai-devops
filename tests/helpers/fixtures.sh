#!/usr/bin/env bash

crear_fixture() {
  FIXTURE="$(mktemp -d)"
  export FAKE_LOG_DIR="$FIXTURE/fake-logs"
  export AI_QUEUE_DIR="$FIXTURE/queue"
  export AI_STATE_DIR="$FIXTURE/state"
  export HOME="$FIXTURE/home"
  export ENV_FILE="$FIXTURE/no-env"
  export AI_SECRETS_DIR="$FIXTURE/secrets"
  mkdir -p "$FAKE_LOG_DIR" "$AI_QUEUE_DIR" "$AI_STATE_DIR" "$HOME" "$AI_SECRETS_DIR"
  chmod 700 "$AI_SECRETS_DIR"
  printf 'token-de-prueba\n' >"$AI_SECRETS_DIR/telegram_bot_token"
  chmod 600 "$AI_SECRETS_DIR/telegram_bot_token"
  export GH_TOKEN=token-de-prueba
  export PATH="$TEST_ROOT/helpers/fake-bin:$PATH"
}

limpiar_fixture() {
  [[ -z "${FIXTURE:-}" ]] || rm -rf -- "$FIXTURE"
}

esperar_archivo() {
  local archivo="$1" intentos=100
  while [[ ! -e "$archivo" && $intentos -gt 0 ]]; do
    sleep 0.02
    ((intentos-=1))
  done
  [[ -e "$archivo" ]]
}
