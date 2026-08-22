#!/usr/bin/env bash
# Primitivas para ejecutar Codex sin degradar el aislamiento ni heredar
# credenciales que el agente no necesita.

codex_sandbox() {
  local solicitado="$1"
  case "$solicitado" in
    read-only|workspace-write) ;;
    *)
      echo "Modo de sandbox no permitido: $solicitado" >&2
      return 64
      ;;
  esac

  if ! unshare -Ur true >/dev/null 2>&1; then
    echo "Este host no permite user namespaces; no es seguro ejecutar Codex sin sandbox." >&2
    echo "Habilita user namespaces o ejecuta el runner en una VM/contenedor aislado." >&2
    return 69
  fi
  printf '%s' "$solicitado"
}

codex_ejecutar_aislado() {
  : "${OMNIROUTE_API_KEY:?falta OMNIROUTE_API_KEY}"
  env -i \
    PATH="$PATH" \
    HOME="$HOME" \
    CODEX_HOME="${CODEX_HOME:-$HOME/.codex}" \
    LANG="${LANG:-C.UTF-8}" \
    OMNIROUTE_API_KEY="$OMNIROUTE_API_KEY" \
    codex "$@"
}
