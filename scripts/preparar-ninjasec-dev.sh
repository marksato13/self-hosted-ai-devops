#!/usr/bin/env bash
# Prepara un entorno local de NinjaSec sin imprimir ni versionar secretos.
set -euo pipefail
RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="$RAIZ/.env"
set -a; source "$ENV_FILE"; set +a
OBJETIVO="${AI_TARGET_REPO_DIR:?AI_TARGET_REPO_DIR no está definido}"
PYMK="$OBJETIVO/PY-MK"
ORIGEN="$PYMK/.env.example"
DESTINO="$PYMK/.env"
[[ -f "$ORIGEN" ]] || { echo "Falta $ORIGEN." >&2; exit 66; }
if [[ -f "$DESTINO" ]]; then
  chmod 600 "$DESTINO"
  echo "Ya existe $DESTINO; no se sobrescribió."
  exit 0
fi
umask 077
tmp="$(mktemp "$PYMK/.env.XXXXXX")"
trap 'rm -f -- "$tmp"' EXIT
cp -- "$ORIGEN" "$tmp"
postgres_password="$(openssl rand -hex 32)"
jwt_secret="$(openssl rand -hex 64)"
sed -i \
  -e "s#^POSTGRES_PASSWORD=.*#POSTGRES_PASSWORD=$postgres_password#" \
  -e "s#^JWT_SECRET_KEY=.*#JWT_SECRET_KEY=$jwt_secret#" \
  "$tmp"
chmod 600 "$tmp"
mv -- "$tmp" "$DESTINO"
trap - EXIT
echo "Entorno local NinjaSec preparado en $DESTINO (secreto no mostrado)."
