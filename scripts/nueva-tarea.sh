#!/usr/bin/env bash
# ============================================================
#  nueva-tarea.sh — prepara los worktrees de una tarea
# ============================================================
#  Crea un worktree por agente, cada uno en su rama, todos
#  compartiendo un solo .git. Es lo que permite que los tres
#  agentes trabajen en paralelo sin pisarse.
#
#  Uso:   ./scripts/nueva-tarea.sh 12
#         ./scripts/nueva-tarea.sh 12 backend tests
#
#  Ver docs/decisiones.md — ADR-011
# ============================================================
set -euo pipefail

ISSUE="${1:-}"
if [[ -z "$ISSUE" ]]; then
  echo "Uso: $0 <numero-de-issue> [agentes...]" >&2
  echo "Ejemplo: $0 12 backend tests docs" >&2
  exit 1
fi
shift || true
AGENTES=("${@:-backend tests docs}")
[[ $# -eq 0 ]] && AGENTES=(backend tests docs)

REPO_RAIZ="$(git rev-parse --show-toplevel)"
BASE_WT="$(dirname "$REPO_RAIZ")/worktrees"
cd "$REPO_RAIZ"

echo "▶ Actualizando main…"
git fetch origin main --quiet
git checkout main --quiet
git pull --ff-only origin main --quiet

mkdir -p "$BASE_WT"

rama_de() {
  case "$1" in
    backend) echo "feat/issue-${ISSUE}-backend" ;;
    tests)   echo "test/issue-${ISSUE}" ;;
    docs)    echo "docs/issue-${ISSUE}" ;;
    *)       echo "feat/issue-${ISSUE}-$1" ;;
  esac
}

for agente in "${AGENTES[@]}"; do
  rama="$(rama_de "$agente")"
  ruta="${BASE_WT}/issue-${ISSUE}-${agente}"

  if [[ -d "$ruta" ]]; then
    echo "⏭  ${agente}: el worktree ya existe → ${ruta}"
    continue
  fi

  # Rama nueva desde main, salvo que ya exista (reintento de una tarea)
  if git show-ref --verify --quiet "refs/heads/${rama}"; then
    git worktree add "$ruta" "$rama" --quiet
  else
    git worktree add -b "$rama" "$ruta" main --quiet
  fi
  echo "✅ ${agente}: ${rama}  →  ${ruta}"
done

echo
echo "Worktrees listos. Cada agente corre en el suyo:"
for agente in "${AGENTES[@]}"; do
  perfil="$agente"
  [[ "$agente" == "tests" ]] && perfil="tester"
  echo "  cd ${BASE_WT}/issue-${ISSUE}-${agente} && codex --profile ${perfil} \"…\""
done
echo
echo "Al terminar:  ./scripts/limpiar-worktrees.sh ${ISSUE}"
