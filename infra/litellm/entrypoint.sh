#!/bin/sh
set -eu
cargar() {
  nombre="$1" archivo="/run/secrets/$2"
  [ -f "$archivo" ] || return 0
  valor="$(cat "$archivo")"; [ -n "$valor" ] || return 0
  export "$nombre=$valor"
}
cargar LITELLM_MASTER_KEY litellm_master_key
cargar OPENAI_API_KEY openai_api_key
cargar ANTHROPIC_API_KEY anthropic_api_key
cargar OPENROUTER_API_KEY openrouter_api_key
: "${LITELLM_MASTER_KEY:?falta el secreto litellm_master_key}"
exec litellm --config /app/config.yaml --host 0.0.0.0 --port 4000
