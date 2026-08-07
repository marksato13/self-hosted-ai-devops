#!/usr/bin/env bash
set -euo pipefail

REPO_RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="${ENV_DESTINO:-$REPO_RAIZ/.env}"

[[ -f "$ENV_FILE" ]] || { echo "No existe $ENV_FILE" >&2; exit 66; }
command -v openssl >/dev/null || { echo "Falta openssl." >&2; exit 69; }

umask 077
jwt="$(openssl rand -base64 48 | tr -d '\n')"
api_secret="$(openssl rand -hex 32)"
storage="$(openssl rand -hex 32)"
password="$(openssl rand -base64 24 | tr -d '\n')"
tmp="${ENV_FILE}.tmp.$$"

awk -v jwt="$jwt" -v api_secret="$api_secret" -v storage="$storage" -v password="$password" '
  BEGIN {
    drop["LITELLM_MASTER_KEY"]=1; drop["POSTGRES_PASSWORD"]=1;
    drop["OPENAI_API_KEY"]=1; drop["DEEPSEEK_API_KEY"]=1;
    drop["DASHSCOPE_API_KEY"]=1; drop["ZHIPU_API_KEY"]=1;
    drop["MOONSHOT_API_KEY"]=1; drop["LITELLM_KEY_PLANNER"]=1;
    drop["LITELLM_KEY_BACKEND"]=1; drop["LITELLM_KEY_TESTER"]=1;
    drop["LITELLM_KEY_DOCS"]=1; drop["LITELLM_KEY_REVIEWER"]=1;
    drop["LITELLM_KEY_DESIGNER"]=1;
  }
  /^[A-Z0-9_]+=/ {
    split($0, parts, "=");
    if (parts[1] in drop) next;
    if (parts[1] == "MONTHLY_BUDGET_USD") { print "MONTHLY_BUDGET_USD=0"; next }
  }
  { print }
  END {
    print "";
    print "# OmniRoute: secretos locales; no compartir ni commitear.";
    print "OMNIROUTE_JWT_SECRET=" jwt;
    print "OMNIROUTE_API_KEY_SECRET=" api_secret;
    print "OMNIROUTE_STORAGE_ENCRYPTION_KEY=" storage;
    print "OMNIROUTE_INITIAL_PASSWORD=" password;
    print "OMNIROUTE_API_KEY=";
    print "OMNIROUTE_PORT=20128";
  }
' "$ENV_FILE" > "$tmp"

chmod 600 "$tmp"
mv -- "$tmp" "$ENV_FILE"
echo "Entorno migrado a OmniRoute. Las claves comerciales fueron eliminadas."
echo "Guardá OMNIROUTE_INITIAL_PASSWORD en tu gestor de contraseñas."
