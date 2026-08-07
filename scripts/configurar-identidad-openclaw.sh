#!/usr/bin/env bash
set -euo pipefail

REPO_RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="${ENV_FILE:-$REPO_RAIZ/.env}"
ORIGEN="$REPO_RAIZ/config/openclaw-workspace"

[[ -f "$ENV_FILE" ]] || { echo "No existe $ENV_FILE." >&2; exit 66; }
set -a
source "$ENV_FILE"
set +a

DESTINO="${OPENCLAW_CONFIG_DIR:?OPENCLAW_CONFIG_DIR no está definido}/workspace"
[[ -d "$DESTINO" ]] || { echo "No existe el workspace de OpenClaw." >&2; exit 66; }

for nombre in AGENTS.md SOUL.md IDENTITY.md USER.md TOOLS.md HEARTBEAT.md; do
  install -m 0644 "$ORIGEN/$nombre" "$DESTINO/$nombre"
done

if [[ -f "$DESTINO/BOOTSTRAP.md" ]]; then
  mv -- "$DESTINO/BOOTSTRAP.md" "$DESTINO/BOOTSTRAP.md.disabled"
fi

echo "Identidad Nexo instalada. El onboarding quedó deshabilitado."
