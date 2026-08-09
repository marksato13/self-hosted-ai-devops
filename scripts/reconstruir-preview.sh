#!/usr/bin/env bash
# Reconstruye el preview en vivo de ninjasec-platform si main avanzó.
# Pensado para correr en loop vía systemd timer (preview-rebuild.timer),
# no vía el pipeline de agentes: el merge a main puede llegar por Telegram
# o a mano, y este script no necesita saber por cuál vía llegó.
set -euo pipefail

REPO="${NINJASEC_REPO:-/home/m4rk/workspace/ninjasec-platform}"
COMPOSE_DIR="${REPO}/PY-MK/infra"
ENV_FILE="${REPO}/PY-MK/.env"
LOCK="/tmp/reconstruir-preview.lock"

exec 9>"$LOCK"
flock -n 9 || { echo "Ya hay una reconstrucción en curso, salgo."; exit 0; }

cd "$REPO"

if ! git diff --quiet || ! git diff --cached --quiet; then
  echo "⚠️  Hay cambios sin commitear en $REPO — no toco nada, reviso a mano."
  exit 0
fi

git fetch origin main --quiet
LOCAL=$(git rev-parse HEAD)
REMOTO=$(git rev-parse origin/main)

if [[ "$LOCAL" == "$REMOTO" ]]; then
  exit 0
fi

echo "▶ main avanzó ($LOCAL → $REMOTO). Reconstruyendo preview…"
git merge --ff-only origin/main

cd "$COMPOSE_DIR"
docker compose --env-file "$ENV_FILE" up -d --build

echo "✅ Preview reconstruido sobre $(git -C "$REPO" rev-parse --short HEAD)."
