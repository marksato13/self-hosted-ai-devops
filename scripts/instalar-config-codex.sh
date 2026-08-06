#!/usr/bin/env bash
set -euo pipefail

REPO_RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DESTINO="${CODEX_HOME:-$HOME/.codex}"
mkdir -p "$DESTINO"

if [[ -e "$DESTINO/config.toml" ]]; then
  echo "Ya existe $DESTINO/config.toml; no se sobrescribe." >&2
  exit 73
fi

install -m 0600 "$REPO_RAIZ/config/codex-config.toml.example" "$DESTINO/config.toml"
for origen in "$REPO_RAIZ"/config/codex-profiles/*.config.toml.example; do
  nombre="$(basename "$origen" .example)"
  install -m 0600 "$origen" "$DESTINO/$nombre"
done

echo "Configuración instalada en $DESTINO."
echo "Carga .env en el entorno antes de ejecutar los perfiles."
