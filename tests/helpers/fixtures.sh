#!/usr/bin/env bash

crear_fixture() {
  FIXTURE="$(mktemp -d)"
  export FAKE_LOG_DIR="$FIXTURE/fake-logs"
  export AI_QUEUE_DIR="$FIXTURE/queue"
  export AI_STATE_DIR="$FIXTURE/state"
  export HOME="$FIXTURE/home"
  mkdir -p "$FAKE_LOG_DIR" "$AI_QUEUE_DIR" "$AI_STATE_DIR" "$HOME"
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
