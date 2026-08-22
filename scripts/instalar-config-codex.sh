#!/usr/bin/env bash
set -euo pipefail

REPO_RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DESTINO="${CODEX_HOME:-$HOME/.codex}"
mkdir -p "$DESTINO"

if [[ -e "$DESTINO/config.toml" ]]; then
  if ! grep -q '^# BEGIN self-hosted-ai-devops LiteLLM$' "$DESTINO/config.toml"; then
    printf '\n' >> "$DESTINO/config.toml"
    cat "$REPO_RAIZ/config/codex-litellm.fragment.toml" >> "$DESTINO/config.toml"
  fi
else
  install -m 0600 "$REPO_RAIZ/config/codex-config.toml.example" "$DESTINO/config.toml"
fi
for origen in "$REPO_RAIZ"/config/codex-profiles/*.config.toml.example; do
  nombre="$(basename "$origen" .example)"
  install -m 0600 "$origen" "$DESTINO/$nombre"
done

echo "Configuración instalada en $DESTINO."
echo "Los perfiles leen LITELLM_MASTER_KEY desde el directorio de secretos del runner."
