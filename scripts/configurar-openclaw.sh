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
[[ -n "${AI_QUEUE_DIR:-}" ]] || { echo "AI_QUEUE_DIR no está definido." >&2; exit 65; }
install -d -m 0700 "$AI_QUEUE_DIR" "$AI_QUEUE_DIR/control"

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
  tools:{allow:[]},
  plugins:{
    enabled:true,
    load:{paths:["/opt/openclaw-plugins/flota-control"]},
    entries:{"flota-control":{enabled:true}}
  },
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

# No se permite exec desde el modelo. Los comandos críticos los procesa el
# plugin flota-control antes del LLM y solo deposita sobres JSON validados.
APROBACIONES="$OPENCLAW_CONFIG_DIR/exec-approvals.json"
mkdir -p "$OPENCLAW_CONFIG_DIR"
tmp_aprobaciones="$(mktemp "$OPENCLAW_CONFIG_DIR/.exec-approvals.XXXXXX")"
trap 'rm -f -- "$tmp_aprobaciones"' EXIT
if [[ -f "$APROBACIONES" ]]; then
  jq '
    .version = 1 |
    .defaults = {security:"deny",ask:"off",askFallback:"deny",autoAllowSkills:false} |
    .agents.main = {security:"deny",ask:"off",askFallback:"deny",autoAllowSkills:false,allowlist:[]}
  ' "$APROBACIONES" >"$tmp_aprobaciones"
else
  jq -n '{
    version:1,
    defaults:{security:"deny",ask:"off",askFallback:"deny",autoAllowSkills:false},
    agents:{main:{security:"deny",ask:"off",askFallback:"deny",autoAllowSkills:false,allowlist:[]}}
  }' >"$tmp_aprobaciones"
fi
chmod 600 "$tmp_aprobaciones"
mv -- "$tmp_aprobaciones" "$APROBACIONES"
trap - EXIT

docker compose --env-file "$ENV_FILE" -f "$COMPOSE" run --rm -T \
  --entrypoint node openclaw-gateway dist/index.js config validate
"$REPO_RAIZ/scripts/configurar-identidad-openclaw.sh"
docker compose --env-file "$ENV_FILE" -f "$COMPOSE" up -d --force-recreate openclaw-gateway

echo "OpenClaw configurado con Telegram en allowlist y OmniRoute como modelo."
echo "Falta probar: tu cuenta recibe respuesta y otra cuenta es ignorada."
