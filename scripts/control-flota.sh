#!/usr/bin/env bash
# Frontera cerrada entre OpenClaw y el runner del host.
# No interpreta shell: valida una acción y escribe un sobre JSON atómico.
set -euo pipefail

accion="${1:-}"
valor="${2:-}"
cola="${AI_QUEUE_DIR:-/queue}/control"
contexto="${OPENCLAW_CHANNEL_CONTEXT:-}"
permitidos=",${TELEGRAM_ALLOWED_CHAT_IDS:-},"

if [[ "$contexto" =~ \"sender\"[[:space:]]*:[[:space:]]*\{[^\}]*\"id\"[[:space:]]*:[[:space:]]*\"([0-9]+)\" ]]; then
  actor="${BASH_REMATCH[1]}"
elif [[ "$contexto" =~ \"sender_id\"[[:space:]]*:[[:space:]]*\"([0-9]+)\" ]]; then
  actor="${BASH_REMATCH[1]}"
else
  echo "Solicitud rechazada: falta la identidad verificable del remitente." >&2
  exit 77
fi
[[ "$permitidos" == *",$actor,"* ]] || {
  echo "Solicitud rechazada: remitente fuera de la allowlist." >&2
  exit 77
}
[[ -d "$cola" && -w "$cola" ]] || {
  echo "El canal de control no está disponible." >&2
  exit 69
}

case "$accion" in
  estado|siguiente|detener|reanudar|ayuda)
    [[ -z "$valor" ]] || { echo "La acción $accion no admite argumentos." >&2; exit 64; }
    ;;
  issue|aprobar|rechazar)
    [[ "$valor" =~ ^[1-9][0-9]{0,9}$ ]] || {
      echo "La acción $accion requiere un número positivo." >&2
      exit 64
    }
    ;;
  confirmar)
    [[ "$valor" =~ ^[a-f0-9]{32}$ ]] || {
      echo "El código de confirmación no es válido." >&2
      exit 64
    }
    ;;
  errores)
    [[ -z "$valor" || "$valor" =~ ^[1-9][0-9]{0,9}$ ]] || {
      echo "Uso: errores [número-de-issue]." >&2
      exit 64
    }
    ;;
  *)
    echo "Acción no permitida. Usa: estado, siguiente, issue N, aprobar PR, confirmar CÓDIGO, rechazar PR, detener, reanudar, errores [N] o ayuda." >&2
    exit 64
    ;;
esac

umask 077
id="$(date -u +%Y%m%dT%H%M%SZ)-$$-${RANDOM}"
tmp="$cola/.${id}.tmp"
destino="$cola/${id}.pending"
trap 'rm -f -- "$tmp"' EXIT
printf '{"version":1,"id":"%s","accion":"%s","valor":"%s","actor":"%s","creado":"%s"}\n' \
  "$id" "$accion" "$valor" "$actor" "$(date -u +%FT%TZ)" >"$tmp"
ln -- "$tmp" "$destino"
rm -f -- "$tmp"
trap - EXIT

echo "Solicitud $accion aceptada. Nexo enviará el resultado por Telegram."
