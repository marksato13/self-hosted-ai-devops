#!/usr/bin/env bash
set -euo pipefail

REPO_RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DESTINO="${XDG_CONFIG_HOME:-$HOME/.config}/systemd/user"
mkdir -p "$DESTINO"
install -m 0644 "$REPO_RAIZ/infra/systemd/ai-devops-queue.service" "$DESTINO/"
install -m 0644 "$REPO_RAIZ/infra/systemd/ai-devops-queue.path" "$DESTINO/"
install -m 0644 "$REPO_RAIZ/infra/systemd/ai-devops-queue.timer" "$DESTINO/"
systemctl --user daemon-reload
systemctl --user enable --now ai-devops-queue.path ai-devops-queue.timer
echo "Runner instalado: path inmediato y reconciliación periódica activos."
