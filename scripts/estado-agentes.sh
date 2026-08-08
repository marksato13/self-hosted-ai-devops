#!/usr/bin/env bash
# Resumen seguro y breve de la flota. No imprime logs, prompts ni secretos.
set -euo pipefail
RAIZ_REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="${ENV_FILE:-$RAIZ_REPO/.env}"
if [[ -f "$ENV_FILE" ]]; then
  set -a
  # Solo carga variables; nunca imprime el archivo ni sus valores.
  source "$ENV_FILE"
  set +a
fi
OBJ="${AI_TARGET_REPO_DIR:-$HOME/workspace/${GITHUB_REPO:-ninjasec-platform}}"
ESTADO="${AI_STATE_DIR:-$HOME/.local/state/ai-devops}"
issue=""; fase="sin tarea activa"
for archivo in "$ESTADO"/issues/*/state.json; do
  [[ -f "$archivo" ]] || continue
  n="$(jq -r '.issue // empty' "$archivo" 2>/dev/null || true)"
  [[ "$n" =~ ^[0-9]+$ ]] || continue
  if [[ -z "$issue" || "$n" -gt "$issue" ]]; then
    issue="$n"; fase="$(jq -r '.estado // "desconocido"' "$archivo")"
  fi
done
if [[ -n "$issue" ]]; then printf 'Issue #%s: %s.\n' "$issue" "$fase"; else printf 'No hay issue activo.\n'; fi
for rol in backend tests docs; do
  perfil="$rol"; [[ "$rol" == tests ]] && perfil="tester"
  if pgrep -af "codex exec -p $perfil " >/dev/null 2>&1; then
    printf '%s: trabajando ahora.\n' "$rol"
  elif [[ -n "$issue" && -d "$(dirname "$OBJ")/worktrees/issue-${issue}-${rol}" ]]; then
    printf '%s: asignado, esperando turno o verificación.\n' "$rol"
  else
    printf '%s: sin ejecución activa.\n' "$rol"
  fi
done
if [[ -n "$issue" ]]; then
  wt="$(dirname "$OBJ")/worktrees/issue-${issue}-backend"
  if [[ -d "$wt" ]]; then
    printf 'Backend worktree: %s cambios sin commit.\n' "$(git -C "$wt" status --porcelain 2>/dev/null | wc -l)"
  fi
  if command -v gh >/dev/null 2>&1 && [[ -n "${GITHUB_OWNER:-}" && -n "${GITHUB_REPO:-}" ]]; then
    pr="$(gh pr list --repo "$GITHUB_OWNER/$GITHUB_REPO" --state open --head "integra/issue-$issue" --limit 1 --json number,url --jq '.[0] | if . then "#\(.number) \(.url)" else "ninguno" end' 2>/dev/null || echo 'no disponible')"
    printf 'PR de integración: %s.\n' "$pr"
  fi
fi
