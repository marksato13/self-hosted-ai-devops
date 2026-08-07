#!/usr/bin/env bash
set -euo pipefail

REPO_RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
set -a
[[ -f "$REPO_RAIZ/.env" ]] && source "$REPO_RAIZ/.env"
set +a
# shellcheck source=scripts/lib/estado.sh
source "$REPO_RAIZ/scripts/lib/estado.sh"

case "${1:-}" in
  pausar)
    ai_pausar
    echo "Runner pausado; la tarea activa no se interrumpe."
    ;;
  reanudar)
    ai_reanudar
    systemctl --user start ai-devops-queue.service 2>/dev/null || true
    echo "Runner reanudado."
    ;;
  estado)
    if ai_pausado; then echo "pausado"; else echo "activo"; fi
    ;;
  *)
    echo "Uso: $0 {pausar|reanudar|estado}" >&2
    exit 64
    ;;
esac
