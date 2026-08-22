#!/usr/bin/env bash
set -euo pipefail

TEST_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$TEST_ROOT/.." && pwd)"
source "$TEST_ROOT/helpers/assertions.sh"
source "$TEST_ROOT/helpers/fixtures.sh"
trap limpiar_fixture EXIT
crear_fixture

BIN="$FIXTURE/bin"
mkdir -p "$BIN"
cat >"$BIN/unshare" <<'EOF'
#!/usr/bin/env bash
exit "${FAKE_UNSHARE_RC:-0}"
EOF
cat >"$BIN/codex" <<'EOF'
#!/usr/bin/env bash
env | LC_ALL=C sort >"$0.env"
printf '%s\n' "$@" >"$0.args"
EOF
chmod +x "$BIN/unshare" "$BIN/codex"
export PATH="$BIN:$PATH"

# shellcheck source=scripts/lib/codex-seguro.sh
source "$REPO_ROOT/scripts/lib/codex-seguro.sh"

echo "Caso: conserva exclusivamente modos de sandbox acotados"
afirmar_igual "$(codex_sandbox read-only)" read-only
afirmar_igual "$(codex_sandbox workspace-write)" workspace-write
ejecutar_rc "$FIXTURE/salida" codex_sandbox danger-full-access
afirmar_igual "$RC" 64

echo "Caso: no degrada a acceso total si el host no puede aislar"
export FAKE_UNSHARE_RC=1
ejecutar_rc "$FIXTURE/salida" codex_sandbox workspace-write
afirmar_igual "$RC" 69

echo "Caso: el runner se detiene antes de leer GitHub sin sandbox"
ejecutar_rc "$FIXTURE/salida" "$REPO_ROOT/scripts/ejecutar-issue.sh" 12
afirmar_igual "$RC" 69
afirmar_no_archivo "$FAKE_LOG_DIR/gh.args"
unset FAKE_UNSHARE_RC

echo "Caso: Codex no hereda credenciales ajenas"
export LITELLM_MASTER_KEY=clave-para-el-gateway
export GITHUB_TOKEN=token-github TELEGRAM_BOT_TOKEN=token-telegram OPENCLAW_GATEWAY_TOKEN=token-openclaw
codex_ejecutar_aislado exec -p backend </dev/null
afirmar_contiene "$BIN/codex.env" 'LITELLM_MASTER_KEY=clave-para-el-gateway'
afirmar_no_contiene "$BIN/codex.env" 'GITHUB_TOKEN='
afirmar_no_contiene "$BIN/codex.env" 'TELEGRAM_BOT_TOKEN='
afirmar_no_contiene "$BIN/codex.env" 'OPENCLAW_GATEWAY_TOKEN='

echo "Pruebas offline de aislamiento de Codex superadas."
