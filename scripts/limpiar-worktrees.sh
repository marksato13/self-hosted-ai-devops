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
if [[ ! "$ISSUE" =~ ^[0-9]+$ ]]; then
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

# Capturas del bucle visual. Se regeneran, así que se borran sin
# preguntar — salvo `base/`, que es la línea de referencia de main.
if [[ -f "${REPO_RAIZ}/.env" ]]; then
  ART="$(grep -E '^ARTEFACTOS_DIR=' "${REPO_RAIZ}/.env" | cut -d= -f2- || true)"
  if [[ -n "${ART:-}" && -d "$ART" ]]; then
    for dir in "${ART}"/issue-${ISSUE}-v*; do
      [[ -d "$dir" ]] || continue
      rm -rf "$dir"
      echo "🧹 capturas borradas: $(basename "$dir")"
    done
  fi
fi

echo
echo "✅ Issue #${ISSUE} limpiado."
git worktree list

# El stage queda sirviendo el build de esta tarea: ya no significa nada.
if docker ps --format '{{.Names}}' 2>/dev/null | grep -qx stage; then
  echo
  echo "ℹ️  El stage sigue arriba con el build de esta tarea. Para bajarlo:"
  echo "      docker compose -f infra/docker-compose.yml \\"
  echo "                     -f infra/docker-compose.visual.yml --profile visual stop stage"
  echo "      sudo tailscale serve --https 8443 off"
fi
