#!/usr/bin/env bash
# Selecciona de forma determinista un único issue preparado para la flota.
set -euo pipefail

REPO_RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="${ENV_FILE:-$REPO_RAIZ/.env}"
set -a
[[ -f "$ENV_FILE" ]] && source "$ENV_FILE"
set +a
# shellcheck source=scripts/lib/estado.sh
source "$REPO_RAIZ/scripts/lib/estado.sh"

[[ "${AI_AUTONOMOUS_MODE:-off}" == on ]] || exit 0
ai_pausado && exit 0
command -v gh >/dev/null || { echo "Falta gh." >&2; exit 69; }
command -v jq >/dev/null || { echo "Falta jq." >&2; exit 69; }

OWNER="${GITHUB_OWNER:?falta GITHUB_OWNER}"
REPO="${GITHUB_REPO:?falta GITHUB_REPO}"
QUEUE="${AI_QUEUE_DIR:-$HOME/.local/state/ai-devops/queue}"
mkdir -p "$QUEUE"

# Conservar una sola unidad de trabajo en vuelo, incluida la espera de revisión.
compgen -G "$QUEUE/issue-*.pending" >/dev/null && exit 0
compgen -G "$QUEUE/issue-*.running" >/dev/null && exit 0
abiertos="$(gh pr list --repo "$OWNER/$REPO" --state open --limit 100 \
  --json headRefName --jq '[.[] | select(.headRefName | startswith("integra/issue-"))] | length')"
[[ "$abiertos" =~ ^[0-9]+$ ]] || exit 69
(( abiertos == 0 )) || exit 0

mapfile -t candidatos < <(gh issue list --repo "$OWNER/$REPO" --state open \
  --label 'agente:lista' --limit 100 --json number,labels \
  --jq '[.[] | select([.labels[].name] | index("bloqueada") | not)] | sort_by(.number) | .[].number')
for issue in "${candidatos[@]}"; do
  if AI_QUEUE_DIR="$QUEUE" "$REPO_RAIZ/scripts/solicitar-issue.sh" "$issue" >/dev/null 2>&1; then
    ai_estado_guardar "$issue" selected 0 "seleccionado por el ciclo autónomo"
    echo "Issue #$issue seleccionado automáticamente."
    exit 0
  fi
done
