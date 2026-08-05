#!/usr/bin/env bash
# ============================================================
#  bucle-visual.sh — ver, criticar, corregir, volver a ver
# ============================================================
#  El ciclo completo:
#
#    publicar → capturar → el Diseñador mira → el Backend aplica
#             → recapturar → comparar → ¿mejoró? → informar
#
#  Uso:
#    ./scripts/bucle-visual.sh 12
#    ./scripts/bucle-visual.sh 12 --vueltas 3 --agente backend
#    ./scripts/bucle-visual.sh 12 --solo-mirar    # captura y reporta, sin tocar código
#
#  Códigos: 0 mejoró o quedó igual · 1 empeoró y se revirtió
#           2 error de configuración · 3 el stage no compila
#
#  ⚠️ Escribe commits en la rama del worktree y, si una vuelta
#     empeora las cosas, hace `git reset --hard` sobre ellos.
#     Nunca toca main. Ver docs/bucle-visual.md
# ============================================================
set -uo pipefail

ISSUE=""; AGENTE="backend"; VUELTAS=2; SOLO_MIRAR=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --vueltas)    VUELTAS="$2"; shift 2 ;;
    --agente)     AGENTE="$2";  shift 2 ;;
    --solo-mirar) SOLO_MIRAR=1; shift ;;
    -h|--help)    sed -n '2,20p' "$0"; exit 0 ;;
    *)            ISSUE="$1";   shift ;;
  esac
done
[[ -z "$ISSUE" ]] && { echo "Uso: $0 <numero-de-issue> [--vueltas N] [--solo-mirar]" >&2; exit 2; }

REPO_RAIZ="$(git rev-parse --show-toplevel)"
cd "$REPO_RAIZ"
set -a; source "${REPO_RAIZ}/.env"; set +a
ART="${ARTEFACTOS_DIR:?falta ARTEFACTOS_DIR en .env}"
WT="$(dirname "$REPO_RAIZ")/worktrees/issue-${ISSUE}-${AGENTE}"
[[ -d "$WT" ]] || { echo "No existe el worktree ${WT}" >&2; exit 2; }

violaciones() { jq 'length' "${ART}/$1/accesibilidad.json" 2>/dev/null || echo 999; }
imagenes()    { find "${ART}/$1" -maxdepth 1 -name '*.png' | sort; }

# Punto de retorno: si una vuelta empeora, se vuelve exactamente acá.
SHA_INICIAL="$(git -C "$WT" rev-parse HEAD)"
echo "▶ Issue #${ISSUE} · worktree ${AGENTE} · punto de retorno ${SHA_INICIAL:0:8}"

# ---------- Vuelta 0: el estado actual ----------
./scripts/publicar-stage.sh "$ISSUE" --agente "$AGENTE" || exit 3
./scripts/capturar.sh "issue-${ISSUE}-v0"
A11Y_0="$(violaciones "issue-${ISSUE}-v0")"
echo "  Accesibilidad inicial: ${A11Y_0} hallazgos"

# Regresión contra la línea base de main, si existe.
if [[ -d "${ART}/base" ]]; then
  ./scripts/comparar.sh base "issue-${ISSUE}-v0" || \
    echo "  ⚠️  La rama cambia el aspecto respecto de main. Se revisa abajo."
fi

if [[ $SOLO_MIRAR -eq 1 ]]; then
  ./scripts/reportar.sh "Issue #${ISSUE} · captura del stage · ${A11Y_0} hallazgos de accesibilidad" \
    $(imagenes "issue-${ISSUE}-v0")
  exit 0
fi

# ---------- Vueltas de mejora ----------
A11Y_PREV="$A11Y_0"
ULTIMA=0

for (( v=1; v<=VUELTAS; v++ )); do
  PREV="issue-${ISSUE}-v$((v-1))"
  ACT="issue-${ISSUE}-v${v}"
  echo
  echo "── Vuelta ${v}/${VUELTAS} ──"

  # --- El Diseñador mira las imágenes ---
  # Se le pasan las capturas con -i y el informe objetivo de axe.
  # El prompt completo está en docs/agentes.md — Agente Diseñador.
  ARGS_IMG=(); for img in $(imagenes "$PREV"); do ARGS_IMG+=(-i "$img"); done

  PROPUESTA="${ART}/${PREV}/propuestas.md"
  codex --profile designer "${ARGS_IMG[@]}" "$(cat <<EOF
Sos el Agente Diseñador. Mirá estas capturas del sitio en tres tamaños
(móvil 390, tablet 834, escritorio 1440) y este informe de accesibilidad:

$(cat "${ART}/${PREV}/accesibilidad.json")

Revisá SOLO esta lista, en este orden. No opines sobre gusto ni paleta:
 1. Contenido cortado, desbordado o superpuesto en algún tamaño.
 2. Texto ilegible por contraste (los hallazgos de axe son la prueba).
 3. Áreas táctiles menores a 44x44 px en móvil.
 4. Espaciados incoherentes entre elementos equivalentes.
 5. Elementos que se salen de la grilla o del ancho del viewport.

Devolvé un markdown con una sección por problema:
  ## <problema>  ·  archivo: <ruta>  ·  severidad: alta|media|baja
  Qué se ve · Qué cambiar (selector CSS y propiedad concreta)

Si no encontrás ningún problema de esa lista, respondé exactamente:
SIN-CAMBIOS
EOF
)" > "$PROPUESTA" 2>&1

  if grep -q '^SIN-CAMBIOS' "$PROPUESTA"; then
    echo "  El Diseñador no encontró problemas objetivos. Fin del bucle."
    break
  fi
  echo "  Propuestas → ${PROPUESTA}"

  # --- El Backend aplica ---
  ( cd "$WT" && codex --profile backend "$(cat <<EOF
Aplicá estos cambios de diseño. Tocá SOLO CSS/estilos y marcado
estrictamente necesario; no cambies lógica, rutas ni dependencias.
Al terminar, hacé un commit con el mensaje:
  "Ajustes de diseño, vuelta ${v} del bucle visual"

$(cat "$PROPUESTA")
EOF
)" ) || { echo "  ❌ El agente Backend falló."; break; }

  # --- Volver a mirar ---
  ./scripts/publicar-stage.sh "$ISSUE" --agente "$AGENTE" || { echo "  ❌ El build se rompió."; break; }
  ./scripts/capturar.sh "$ACT"
  ./scripts/comparar.sh "$PREV" "$ACT" >/dev/null
  A11Y_ACT="$(violaciones "$ACT")"
  ULTIMA=$v

  echo "  Accesibilidad: ${A11Y_PREV} → ${A11Y_ACT}"

  # --- El único criterio automático que no es cuestión de gusto ---
  if (( A11Y_ACT > A11Y_PREV )); then
    echo "  ❌ Empeoró. Volviendo a ${SHA_INICIAL:0:8}."
    git -C "$WT" reset --hard "$SHA_INICIAL" --quiet
    ./scripts/reportar.sh \
      "Issue #${ISSUE}: el bucle visual empeoró la accesibilidad (${A11Y_PREV} → ${A11Y_ACT}). Revertido. Mirá vos." \
      $(imagenes "$PREV" | head -3) $(imagenes "$ACT" | head -3)
    exit 1
  fi

  if (( A11Y_ACT == A11Y_PREV )); then
    echo "  Sin mejora medible. Se corta acá para no gastar de más."
    break
  fi
  A11Y_PREV="$A11Y_ACT"
done

# ---------- Informe final ----------
FINAL="issue-${ISSUE}-v${ULTIMA}"
echo
echo "▶ Informe: v0 (${A11Y_0}) → v${ULTIMA} (${A11Y_PREV})"

./scripts/reportar.sh \
  "$(printf 'Issue #%s · bucle visual terminado\nAccesibilidad: %s → %s hallazgos\nVueltas: %s\nStage: https://<tu-host>.ts.net:8443' \
     "$ISSUE" "$A11Y_0" "$A11Y_PREV" "$ULTIMA")" \
  $(imagenes "issue-${ISSUE}-v0" | head -3) $(imagenes "$FINAL" | head -3)

echo "✅ Listo. Las imágenes están en ${ART}/"
