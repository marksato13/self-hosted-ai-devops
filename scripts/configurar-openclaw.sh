#!/usr/bin/env bash
set -euo pipefail

REPO_RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="${ENV_FILE:-$REPO_RAIZ/.env}"
COMPOSE="$REPO_RAIZ/infra/docker-compose.yml"

[[ -f "$ENV_FILE" ]] || { echo "No existe $ENV_FILE." >&2; exit 66; }
command -v jq >/dev/null || { echo "Falta jq." >&2; exit 69; }

set -a
source "$ENV_FILE"
set +a

[[ "${TELEGRAM_BOT_TOKEN:-}" == *:* ]] || {
  echo "TELEGRAM_BOT_TOKEN no tiene el formato esperado." >&2
  exit 65
}
[[ "${TELEGRAM_ALLOWED_CHAT_IDS:-}" =~ ^[0-9]+([,][0-9]+)*$ ]] || {
  echo "TELEGRAM_ALLOWED_CHAT_IDS debe contener IDs numéricos separados por coma." >&2
  exit 65
}
[[ -n "${OMNIROUTE_API_KEY:-}" ]] || {
  echo "OMNIROUTE_API_KEY no está definida." >&2
  exit 65
}

ids_json="$(jq -nc --arg ids "$TELEGRAM_ALLOWED_CHAT_IDS" '$ids | split(",")')"
patch="$(jq -nc --argjson ids "$ids_json" '{
  gateway: {mode:"local", bind:"lan", auth:{mode:"token"}},
  models: {
    mode:"merge",
    providers:{omniroute:{
      baseUrl:"http://omniroute:20128/v1",
      apiKey:{source:"env",provider:"default",id:"OMNIROUTE_API_KEY"},
      auth:"api-key",
      api:"openai-responses",
      models:[{
        id:"oc/big-pickle",
        name:"OpenCode Big Pickle vía OmniRoute",
        reasoning:true,
        input:["text","image"],
        contextWindow:200000,
        maxTokens:32000,
        agentRuntime:{id:"openclaw"}
      }]
    }}
  },
  agents:{defaults:{model:{primary:"omniroute/oc/big-pickle"}}},
  channels: {telegram:{
    enabled:true,
    botToken:{source:"env",provider:"default",id:"TELEGRAM_BOT_TOKEN"},
    dmPolicy:"allowlist",
    allowFrom:$ids,
    groupPolicy:"disabled"
  }}
}')"

printf '%s' "$patch" | docker compose --env-file "$ENV_FILE" -f "$COMPOSE" \
  run --rm -T --entrypoint node openclaw-gateway \
  dist/index.js config patch --stdin >/dev/null

docker compose --env-file "$ENV_FILE" -f "$COMPOSE" run --rm -T \
  --entrypoint node openclaw-gateway dist/index.js config validate
docker compose --env-file "$ENV_FILE" -f "$COMPOSE" up -d openclaw-gateway

echo "OpenClaw configurado con Telegram en allowlist y OmniRoute como modelo."
echo "Falta probar: tu cuenta recibe respuesta y otra cuenta es ignorada."
