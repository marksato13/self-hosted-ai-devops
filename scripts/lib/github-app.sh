#!/usr/bin/env bash
# Autenticación efímera para gh mediante una GitHub App instalada solo en el
# repositorio objetivo. No persiste el token ni invoca `gh auth login`.

github_b64url() {
  openssl base64 -A | tr '+/' '-_' | tr -d '='
}

github_configurar_token() {
  [[ -n "${GH_TOKEN:-}" ]] && return 0
  : "${GITHUB_APP_ID:?falta GITHUB_APP_ID}"
  : "${GITHUB_OWNER:?falta GITHUB_OWNER}"
  : "${GITHUB_REPO:?falta GITHUB_REPO}"
  [[ "$GITHUB_APP_ID" =~ ^[1-9][0-9]*$ ]] || { echo "GITHUB_APP_ID inválido." >&2; return 64; }
  command -v curl >/dev/null || { echo "Falta curl." >&2; return 69; }
  command -v jq >/dev/null || { echo "Falta jq." >&2; return 69; }
  command -v openssl >/dev/null || { echo "Falta openssl." >&2; return 69; }
  # shellcheck source=scripts/lib/secretos.sh
  source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/secretos.sh"
  secreto_cargar GITHUB_APP_PRIVATE_KEY github_app_private_key || return $?

  local ahora cabecera carga firma jwt instalacion respuesta token
  ahora="$(date +%s)"
  cabecera="$(printf '%s' '{"alg":"RS256","typ":"JWT"}' | github_b64url)"
  carga="$(jq -cn --argjson iat "$((ahora - 60))" --argjson exp "$((ahora + 540))" --arg iss "$GITHUB_APP_ID" '{iat:$iat,exp:$exp,iss:$iss}' | github_b64url)"
  firma="$(printf '%s.%s' "$cabecera" "$carga" | openssl dgst -sha256 -sign "$(secretos_directorio)/github_app_private_key" -binary | github_b64url)"
  jwt="$cabecera.$carga.$firma"
  instalacion="$(curl -fsS \
    -H "Authorization: Bearer $jwt" -H 'Accept: application/vnd.github+json' \
    "https://api.github.com/repos/$GITHUB_OWNER/$GITHUB_REPO/installation" | jq -er .id)" || {
      echo "No se encontró una instalación de la GitHub App para $GITHUB_OWNER/$GITHUB_REPO." >&2; return 77; }
  respuesta="$(curl -fsS -X POST \
    -H "Authorization: Bearer $jwt" -H 'Accept: application/vnd.github+json' \
    "https://api.github.com/app/installations/$instalacion/access_tokens")" || {
      echo "GitHub rechazó la emisión del token de instalación." >&2; return 75; }
  token="$(jq -er .token <<<"$respuesta")" || { echo "GitHub no devolvió un token de instalación." >&2; return 75; }
  GH_TOKEN="$token"
  export GH_TOKEN
}
