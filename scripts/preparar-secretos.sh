#!/usr/bin/env bash
# Crea únicamente el secreto generado localmente. Los secretos de Telegram,
# GitHub App y proveedores los aporta el operador, nunca este repositorio.
set -euo pipefail

REPO_RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=scripts/lib/secretos.sh
source "$REPO_RAIZ/scripts/lib/secretos.sh"
command -v openssl >/dev/null || { echo "Falta openssl." >&2; exit 69; }
DIRECTORIO="$(secretos_directorio)"
mkdir -p "$DIRECTORIO"
chmod 700 "$DIRECTORIO"

crear() {
  local nombre="$1" destino="$DIRECTORIO/$nombre"
  [[ ! -e "$destino" ]] || { echo "Ya existe $destino; no se sobrescribe." >&2; return 0; }
  umask 077
  openssl rand -hex 32 >"$destino"
  chmod 600 "$destino"
  echo "Creado $destino."
}

crear litellm_master_key
for opcional in openai_api_key anthropic_api_key openrouter_api_key whatsapp_token; do
  destino="$DIRECTORIO/$opcional"
  if [[ ! -e "$destino" ]]; then
    : >"$destino"
    chmod 600 "$destino"
  fi
done
cat <<EOF
Pendientes manuales (chmod 600):
  $DIRECTORIO/telegram_bot_token
  $DIRECTORIO/github_app_private_key
  $DIRECTORIO/openai_api_key, anthropic_api_key u openrouter_api_key (solo los proveedores usados)
EOF
