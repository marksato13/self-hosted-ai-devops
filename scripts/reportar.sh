#!/usr/bin/env bash
# ============================================================
#  reportar.sh — manda el resultado al celular, con imágenes
# ============================================================
#  Uso:
#    ./scripts/reportar.sh "PR #12 listo" antes.png despues.png
#    ./scripts/reportar.sh "Sin regresiones visuales"
#
#  Canales (se configuran en .env):
#    Telegram   — siempre. Es el canal fiable para imágenes.
#    WhatsApp   — opcional, según WHATSAPP_MODO: off | cloud | openclaw
#
#  Por qué Telegram lleva las imágenes y WhatsApp no:
#  ver docs/decisiones.md — ADR-016
# ============================================================
set -uo pipefail

MENSAJE="${1:-}"; shift || true
IMAGENES=("$@")
[[ -z "$MENSAJE" ]] && { echo "Uso: $0 \"<mensaje>\" [imagen.png …]" >&2; exit 1; }

REPO_RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="${ENV_FILE:-$REPO_RAIZ/.env}"
[[ -f "$ENV_FILE" ]] || { echo "Falta el archivo de entorno del notificador." >&2; exit 1; }
set -a; source "$ENV_FILE"; set +a
# shellcheck source=scripts/lib/secretos.sh
source "$REPO_RAIZ/scripts/lib/secretos.sh"

secreto_cargar TELEGRAM_BOT_TOKEN telegram_bot_token
: "${TELEGRAM_ALLOWED_CHAT_IDS:?falta TELEGRAM_ALLOWED_CHAT_IDS en .env}"

# El informe va SOLO a los chat_id de la allowlist: el mismo
# criterio con el que el bot decide a quién obedecer.
API="https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}"
FALLOS=0

telegram_api() {
  local respuesta
  respuesta="$(mktemp)"
  if ! curl --fail-with-body -sS -o "$respuesta" "$@"; then
    rm -f -- "$respuesta"
    return 1
  fi
  jq -e '.ok == true' "$respuesta" >/dev/null 2>&1
  local rc=$?
  rm -f -- "$respuesta"
  return "$rc"
}

DESTINOS="${TELEGRAM_ALLOWED_CHAT_IDS//,/ }"
if [[ -n "${TELEGRAM_DESTINO_CHAT_ID:-}" ]]; then
  case ",${TELEGRAM_ALLOWED_CHAT_IDS}," in
    *",${TELEGRAM_DESTINO_CHAT_ID},"*) DESTINOS="$TELEGRAM_DESTINO_CHAT_ID" ;;
    *) echo "TELEGRAM_DESTINO_CHAT_ID no pertenece a la allowlist." >&2; exit 1 ;;
  esac
fi

for CHAT in $DESTINOS; do

  # ---------- sin imágenes: texto y listo ----------
  if [[ ${#IMAGENES[@]} -eq 0 ]]; then
    telegram_api -X POST "${API}/sendMessage" \
      -d chat_id="$CHAT" --data-urlencode text="$MENSAJE" || ((FALLOS++))
    continue
  fi

  # ---------- una imagen: sendPhoto ----------
  if [[ ${#IMAGENES[@]} -eq 1 ]]; then
    telegram_api -X POST "${API}/sendPhoto" \
      -F chat_id="$CHAT" -F caption="$MENSAJE" \
      -F photo=@"${IMAGENES[0]}" || ((FALLOS++))
    continue
  fi

  # ---------- varias: sendMediaGroup, máximo 10 por álbum ----------
  # El caption va solo en la primera, que es como Telegram lo muestra.
  ARGS=(); MEDIA='[]'; i=0
  for img in "${IMAGENES[@]:0:10}"; do
    [[ -f "$img" ]] || { echo "⚠️  no existe: $img" >&2; continue; }
    ARGS+=(-F "f${i}=@${img}")
    MEDIA="$(jq -c --arg a "attach://f${i}" --arg c "$MENSAJE" --argjson primero "$([[ $i -eq 0 ]] && echo true || echo false)" \
      '. + [ if $primero then {type:"photo",media:$a,caption:$c} else {type:"photo",media:$a} end ]' <<<"$MEDIA")"
    ((i++))
  done
  telegram_api -X POST "${API}/sendMediaGroup" \
    -F chat_id="$CHAT" -F media="$MEDIA" "${ARGS[@]}" || ((FALLOS++))
done

# ============================================================
#  WhatsApp — opcional
# ============================================================
case "${WHATSAPP_MODO:-off}" in

  off) : ;;

  # --- API oficial de Meta (Cloud API) ---------------------
  # ⚠️ Solo se puede enviar texto libre dentro de las 24 h desde
  #    el último mensaje del usuario. Fuera de esa ventana hace
  #    falta una plantilla aprobada. Un informe de madrugada
  #    puede NO llegar. Por eso el canal principal es Telegram.
  cloud)
    secreto_cargar WHATSAPP_TOKEN whatsapp_token
    : "${WHATSAPP_PHONE_ID:?falta WHATSAPP_PHONE_ID}"
    : "${WHATSAPP_DESTINO:?falta WHATSAPP_DESTINO}"
    G="https://graph.facebook.com/v21.0/${WHATSAPP_PHONE_ID}"

    if [[ ${#IMAGENES[@]} -gt 0 && -f "${IMAGENES[0]}" ]]; then
      ID="$(curl -sS -X POST "${G}/media" \
              -H "Authorization: Bearer ${WHATSAPP_TOKEN}" \
              -F messaging_product=whatsapp \
              -F type=image/png \
              -F file=@"${IMAGENES[0]}" | jq -r '.id // empty')"
      if [[ -n "$ID" ]]; then
        curl -sS -o /dev/null -X POST "${G}/messages" \
          -H "Authorization: Bearer ${WHATSAPP_TOKEN}" \
          -H "Content-Type: application/json" \
          -d "$(jq -n --arg to "$WHATSAPP_DESTINO" --arg id "$ID" --arg c "$MENSAJE" \
                '{messaging_product:"whatsapp",to:$to,type:"image",image:{id:$id,caption:$c}}')" \
          || ((FALLOS++))
      else
        echo "⚠️  WhatsApp: falló la subida de la imagen." >&2; ((FALLOS++))
      fi
    else
      curl -sS -o /dev/null -X POST "${G}/messages" \
        -H "Authorization: Bearer ${WHATSAPP_TOKEN}" \
        -H "Content-Type: application/json" \
        -d "$(jq -n --arg to "$WHATSAPP_DESTINO" --arg t "$MENSAJE" \
              '{messaging_product:"whatsapp",to:$to,type:"text",text:{body:$t}}')" || ((FALLOS++))
    fi
    ;;

  *) echo "WHATSAPP_MODO desconocido: ${WHATSAPP_MODO}" >&2; ((FALLOS++)) ;;
esac

if [[ $FALLOS -gt 0 ]]; then
  echo "❌ ${FALLOS} envío(s) fallaron." >&2
  exit 1
fi
echo "✅ Informe enviado (${#IMAGENES[@]} imagen/es)."
