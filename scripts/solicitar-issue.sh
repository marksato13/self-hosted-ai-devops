#!/usr/bin/env sh
set -eu

issue=${1:-}
case "$issue" in
  ''|*[!0-9]*)
    echo "Uso: solicitar-issue <numero>" >&2
    exit 64
    ;;
esac

queue=${AI_QUEUE_DIR:-/queue}
test -d "$queue" || {
  echo "La cola no está disponible." >&2
  exit 69
}

umask 077
tmp="$queue/.issue-${issue}.$$"
pending="$queue/issue-${issue}.pending"
printf '%s\n' "$issue" > "$tmp"
if ln "$tmp" "$pending" 2>/dev/null; then
  rm -f "$tmp"
  echo "Issue #${issue} aceptado."
else
  rm -f "$tmp"
  echo "El issue #${issue} ya está en la cola." >&2
  exit 75
fi
