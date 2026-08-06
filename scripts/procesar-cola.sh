#!/usr/bin/env bash
set -euo pipefail

REPO_RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
set -a
[[ -f "$REPO_RAIZ/.env" ]] && source "$REPO_RAIZ/.env"
set +a

QUEUE="${AI_QUEUE_DIR:-$HOME/.local/state/ai-devops/queue}"
mkdir -p "$QUEUE" "$QUEUE/completadas" "$QUEUE/fallidas"
exec 9>"$QUEUE/.procesador.lock"
flock -n 9 || { echo "Ya hay otro procesador activo." >&2; exit 75; }

procesadas=0
shopt -s nullglob
for solicitud in "$QUEUE"/issue-*.pending; do
  issue="$(<"$solicitud")"
  [[ "$issue" =~ ^[0-9]+$ ]] || {
    mv -- "$solicitud" "$QUEUE/fallidas/$(basename "$solicitud").invalida"
    continue
  }
  running="$QUEUE/issue-${issue}.running"
  mv -- "$solicitud" "$running"
  if "$REPO_RAIZ/scripts/ejecutar-issue.sh" "$issue"; then
    mv -- "$running" "$QUEUE/completadas/issue-${issue}.done"
  else
    rc=$?
    printf '%s\n' "$rc" > "$QUEUE/fallidas/issue-${issue}.exit"
    mv -- "$running" "$QUEUE/fallidas/issue-${issue}.failed"
  fi
  ((procesadas+=1))
done

echo "Solicitudes procesadas: $procesadas"
