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
for existente in "$queue/issue-${issue}.pending" "$queue/issue-${issue}.running" \
  "$queue/completadas/issue-${issue}.done"; do
  if [ -e "$existente" ]; then
    echo "El issue #${issue} ya fue solicitado." >&2
    exit 75
  fi
done
if [ -e "$queue/fallidas/issue-${issue}.failed" ] && [ "${AI_MANUAL_REQUEUE:-0}" != 1 ]; then
  echo "El issue #${issue} agotó reintentos; requiere reencolado manual autorizado." >&2
  exit 75
fi
printf '%s\n' "$issue" > "$tmp"
if ln "$tmp" "$pending" 2>/dev/null; then
  rm -f "$tmp"
  if [ "${AI_MANUAL_REQUEUE:-0}" = 1 ] && [ -e "$queue/fallidas/issue-${issue}.failed" ]; then
    mkdir -p "$queue/fallidas/reintentadas"
    mv "$queue/fallidas/issue-${issue}.failed" \
      "$queue/fallidas/reintentadas/issue-${issue}.$(date -u +%Y%m%dT%H%M%SZ).failed"
  fi
  echo "Issue #${issue} aceptado."
else
  rm -f "$tmp"
  echo "El issue #${issue} ya está en la cola." >&2
  exit 75
fi
