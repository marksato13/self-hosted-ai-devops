#!/usr/bin/env bash
# Carga secretos del directorio privado del operador. Los agentes nunca heredan
# estas variables: codex-seguro.sh construye un entorno mínimo por llamada.

secretos_directorio() {
  printf '%s' "${AI_SECRETS_DIR:-${XDG_CONFIG_HOME:-$HOME/.config}/ai-devops/secrets}"
}

secreto_cargar() {
  local nombre="$1" archivo="${2:-${1,,}}" directorio ruta modo valor
  directorio="$(secretos_directorio)"
  ruta="$directorio/$archivo"
  [[ -f "$ruta" ]] || { echo "Falta el secreto $ruta." >&2; return 78; }
  modo="$(stat -c '%a' "$ruta" 2>/dev/null || true)"
  [[ "$modo" =~ ^[0-7]{3,4}$ ]] || { echo "No se pudieron verificar los permisos de $ruta." >&2; return 69; }
  # No se aceptan archivos legibles por grupo u otros usuarios.
  (( (8#$modo & 8#077) == 0 )) || { echo "Permisos inseguros en $ruta; usa chmod 600." >&2; return 77; }
  valor="$(<"$ruta")"
  [[ -n "$valor" ]] || { echo "El secreto $ruta está vacío." >&2; return 78; }
  printf -v "$nombre" '%s' "$valor"
  export "$nombre"
}
