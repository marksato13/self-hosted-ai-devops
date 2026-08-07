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
  "$queue/completadas/issue-${issue}.done" "$queue/fallidas/issue-${issue}.failed"; do
  if [ -e "$existente" ]; then
    echo "El issue #${issue} ya fue solicitado." >&2
    exit 75
  fi
done
printf '%s\n' "$issue" > "$tmp"
if ln "$tmp" "$pending" 2>/dev/null; then
  rm -f "$tmp"
  echo "Issue #${issue} aceptado."
else
  rm -f "$tmp"
  echo "El issue #${issue} ya está en la cola." >&2
  exit 75
fi
