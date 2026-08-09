#!/usr/bin/env bash
# Emite una línea por cada evento que el modo autónomo nocturno debe atender:
# - un PR nuevo abierto por la flota (o por mí) listo para revisar
# - un issue que cayó en fallidas/ tras agotar sus 3 reintentos
# No fusiona nada — solo notifica. La decisión de fusionar la toma quien
# lee el evento (yo, en el bucle de Claude Code), tras revisar el diff real.
set -uo pipefail

REPO="marksato13/ninjasec-platform"
QUEUE="${AI_STATE_DIR:-$HOME/.local/state/ai-devops}/queue"
SEEN_PR="/tmp/vigilar-prs.seen-pr"
SEEN_FALLO="/tmp/vigilar-prs.seen-fallo"
touch "$SEEN_PR" "$SEEN_FALLO"

while true; do
  # PRs abiertos contra main que todavía no vimos
  gh pr list --repo "$REPO" --state open --json number,title,headRefName \
    --jq '.[] | "\(.number)\t\(.title)\t\(.headRefName)"' 2>/dev/null | while IFS=$'\t' read -r num title branch; do
      if ! grep -qx "$num" "$SEEN_PR"; then
        echo "$num" >> "$SEEN_PR"
        echo "PR_NUEVO #${num} :: ${title} :: ${branch}"
      fi
    done

  # Ramas integra/issue-N empujadas pero sin PR (el mismo fallo silencioso
  # que ya vimos en el issue #13: git push OK, gh pr create falla y nadie
  # abre el PR). Si aparece, la creo yo misma acá — acción reversible, no
  # es un merge.
  for rama in $(git -C "$HOME/workspace/ninjasec-platform" ls-remote --heads origin 'integra/issue-*' 2>/dev/null | sed 's#.*refs/heads/##'); do
    numero="${rama#integra/issue-}"
    ya_tiene_pr=$(gh pr list --repo "$REPO" --state all --head "$rama" --json number --jq 'length' 2>/dev/null || echo 1)
    if [[ "$ya_tiene_pr" == "0" ]]; then
      echo "PR_FALTANTE issue-${numero} :: rama ${rama} empujada sin PR, la creo"
      gh pr create --repo "$REPO" --draft --base main --head "$rama" \
        --title "Issue #${numero}: cambios consolidados de la flota" \
        --body "Recuperación automática: la rama ya estaba integrada y publicada pero \`gh pr create\` había fallado en el pipeline (probable blip de red). Generado por vigilar-prs.sh — revisar el diff igual que cualquier otro PR." \
        2>&1 | tail -3
    fi
  done

  # Issues que se quedaron sin reintentos
  if [[ -d "$QUEUE/fallidas" ]]; then
    for f in "$QUEUE/fallidas"/issue-*.failed; do
      [[ -e "$f" ]] || continue
      base="$(basename "$f" .failed)"
      if ! grep -qx "$base" "$SEEN_FALLO"; then
        echo "$base" >> "$SEEN_FALLO"
        echo "ISSUE_FALLIDO ${base} :: agotó 3 reintentos, revisar manualmente"
      fi
    done
  fi

  sleep 60
done
