#!/usr/bin/env bash
# ============================================================
#  integrar.sh — el trabajo del Agente Revisor
# ============================================================
#  Une las ramas de los agentes en integra/issue-<n>, corre las
#  verificaciones y abre UN SOLO Pull Request en borrador.
#
#  Como los worktrees comparten el mismo .git, las tres ramas ya
#  están acá: no hace falta pasar por GitHub para integrarlas.
#
#  Uso:   ./scripts/integrar.sh 12
#
#  El PR sale en BORRADOR a propósito: el merge lo aprueba una
#  persona, siempre. Ver docs/decisiones.md — ADR-009
# ============================================================
set -euo pipefail

ISSUE="${1:-}"
if [[ ! "$ISSUE" =~ ^[0-9]+$ ]]; then
  echo "Uso: $0 <numero-de-issue>" >&2
  exit 1
fi

REPO_RAIZ="$(git rev-parse --show-toplevel)"
cd "$REPO_RAIZ"

if [[ -n "$(git status --porcelain)" ]]; then
  echo "El repositorio principal tiene cambios sin commitear; se cancela." >&2
  exit 2
fi

RAMA_INT="integra/issue-${ISSUE}"
CANDIDATAS=(
  "feat/issue-${ISSUE}-backend"
  "test/issue-${ISSUE}"
  "docs/issue-${ISSUE}"
)

echo "▶ Preparando ${RAMA_INT} desde main…"
git fetch origin main --quiet
git checkout main --quiet
git pull --ff-only origin main --quiet
if git show-ref --verify --quiet "refs/heads/${RAMA_INT}"; then
  echo "Ya existe ${RAMA_INT}. Revísala o elimínala explícitamente antes de reintentar." >&2
  exit 2
fi
git checkout -b "$RAMA_INT" --quiet

merge_en_curso=0
limpiar_merge() {
  if [[ $merge_en_curso -eq 1 ]]; then
    git merge --abort >/dev/null 2>&1 || true
  fi
}
trap limpiar_merge EXIT

UNIDAS=()
for rama in "${CANDIDATAS[@]}"; do
  if ! git show-ref --verify --quiet "refs/heads/${rama}"; then
    echo "⏭  ${rama}: no existe, se omite"
    continue
  fi
  echo "▶ Uniendo ${rama}…"
  merge_en_curso=1
  if git merge --no-ff --no-edit "$rama" --quiet; then
    merge_en_curso=0
    UNIDAS+=("$rama")
    echo "  ✅ unida"
  else
    echo "  ❌ CONFLICTO en ${rama}"
    echo
    git diff --name-only --diff-filter=U
    echo
    echo "El Revisor debe resolverlo. Si el conflicto es ambiguo," >&2
    echo "escalar al usuario en vez de adivinar." >&2
    exit 2
  fi
done

if [[ ${#UNIDAS[@]} -eq 0 ]]; then
  echo "No había ninguna rama que integrar." >&2
  exit 1
fi

echo
echo "▶ Verificaciones…"

# 1. Secretos — lo primero, antes que nada
command -v gitleaks >/dev/null 2>&1 || {
  echo "  🔴 gitleaks es obligatorio y no está instalado" >&2
  exit 3
}
gitleaks detect --no-banner --redact --log-opts="main..${RAMA_INT}" \
  && echo "  ✅ sin secretos" \
  || { echo "  🔴 SECRETO DETECTADO — no se abre el PR" >&2; exit 3; }

# 2. Tests, si el repo tiene
TEST_ESTADO="OMITIDO (el repositorio no declara una suite compatible)"
if [[ -f package.json ]] && jq -e '.scripts.test' package.json >/dev/null 2>&1; then
  npm test && echo "  ✅ tests" || { echo "  ❌ tests fallaron" >&2; exit 4; }
  TEST_ESTADO="OK"
elif [[ -f pytest.ini || -f pyproject.toml ]] && command -v pytest >/dev/null 2>&1; then
  pytest -q && echo "  ✅ tests" || { echo "  ❌ tests fallaron" >&2; exit 4; }
  TEST_ESTADO="OK"
else
  echo "  ⏭  sin suite de tests en este repo"
fi

# 3. Compose válido — el principal y, si existe, el del bucle visual
if [[ -f infra/docker-compose.yml ]]; then
  COMPOSE_ARGS=(-f infra/docker-compose.yml)
  [[ -f infra/docker-compose.visual.yml ]] && COMPOSE_ARGS+=(-f infra/docker-compose.visual.yml)
  docker compose --env-file .env.example "${COMPOSE_ARGS[@]}" config -q \
    && echo "  ✅ docker-compose válido" \
    || { echo "  ❌ docker-compose inválido" >&2; exit 5; }
fi

# 4. ¿Este cambio toca la interfaz?
# No se decide por el tipo de tarea sino por lo que realmente cambió.
TOCA_UI=0
if git diff --name-only "main..${RAMA_INT}" \
     | grep -qEi '\.(css|scss|sass|less|html|tsx|jsx|vue|svelte)$'; then
  TOCA_UI=1
  echo "  👁️  el diff toca la interfaz — corresponde el bucle visual"
fi

echo
echo "▶ Publicando y abriendo el PR…"
git push -u origin "$RAMA_INT" --quiet

CUERPO="Consolida el trabajo de los agentes sobre el issue #${ISSUE}.

## Ramas integradas
$(printf -- '- \`%s\`\n' "${UNIDAS[@]}")

## Verificaciones
- Escaneo de secretos: OK
- Tests: ${TEST_ESTADO}
- Configuración de Docker: válida

## Antes de aprobar
- [ ] El diff toca solo los archivos previstos
- [ ] No hay claves ni rutas absolutas
- [ ] Las dependencias nuevas están declaradas en el commit
- [ ] Se cumple el criterio de aceptación del plan$( [[ $TOCA_UI -eq 1 ]] && printf '\n- [ ] Revisadas las capturas del antes y el después' )

---
Generado por la flota. **El merge lo aprueba una persona.**"

gh pr create \
  --draft \
  --base main \
  --head "$RAMA_INT" \
  --title "Issue #${ISSUE}: cambios consolidados de la flota" \
  --body "$CUERPO"

echo
echo "✅ Pull Request abierto en borrador."
gh pr view --json url --jq .url

if [[ $TOCA_UI -eq 1 ]]; then
  echo
  echo "👁️  Este cambio toca la interfaz. Falta mirarlo:"
  echo "      ./scripts/bucle-visual.sh ${ISSUE}"
  echo "   (no se dispara solo: necesita un stage que compile y gasta tokens)"
fi
