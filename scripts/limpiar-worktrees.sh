#!/usr/bin/env bash
# ============================================================
#  limpiar-worktrees.sh — cerrar una tarea terminada
# ============================================================
#  Borra los worktrees de un issue y, si la rama ya se mergeó,
#  también la rama local. Sin esto, ~/worktrees se llena de
#  directorios viejos y el disco de la VM se acaba.
#
#  Uso:   ./scripts/limpiar-worktrees.sh 12
#         ./scripts/limpiar-worktrees.sh --listar
# ============================================================
set -euo pipefail

REPO_RAIZ="$(git rev-parse --show-toplevel)"
cd "$REPO_RAIZ"

if [[ "${1:-}" == "--listar" ]]; then
  echo "Worktrees activos:"
  git worktree list
  exit 0
fi

ISSUE="${1:-}"
if [[ -z "$ISSUE" ]]; then
  echo "Uso: $0 <numero-de-issue> | --listar" >&2
  exit 1
fi

BASE_WT="$(dirname "$REPO_RAIZ")/worktrees"

for ruta in "${BASE_WT}"/issue-${ISSUE}-*; do
  [[ -d "$ruta" ]] || continue

  # Avisar si quedó trabajo sin commitear: borrarlo sería perderlo
  if [[ -n "$(git -C "$ruta" status --porcelain 2>/dev/null)" ]]; then
    echo "⚠️  ${ruta} tiene cambios sin commitear:"
    git -C "$ruta" status --short
    read -r -p "   ¿Borrar igual? [s/N] " resp
    [[ "$resp" =~ ^[sS]$ ]] || { echo "   ⏭  se conserva"; continue; }
  fi

  git worktree remove --force "$ruta"
  echo "🧹 borrado: ${ruta}"
done

git worktree prune

# Borrar solo las ramas ya integradas en main. Las demás quedan.
for rama in "feat/issue-${ISSUE}-backend" "test/issue-${ISSUE}" \
            "docs/issue-${ISSUE}" "integra/issue-${ISSUE}"; do
  git show-ref --verify --quiet "refs/heads/${rama}" || continue
  if git branch --merged main | grep -qx "  ${rama}"; then
    git branch -d "$rama" --quiet
    echo "🧹 rama borrada: ${rama}"
  else
    echo "⏭  ${rama}: sin mergear en main, se conserva"
  fi
done

echo
echo "✅ Issue #${ISSUE} limpiado."
git worktree list
