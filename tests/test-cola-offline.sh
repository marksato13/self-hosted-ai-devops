#!/usr/bin/env bash
set -euo pipefail

TEST_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$TEST_ROOT/.." && pwd)"
source "$TEST_ROOT/helpers/assertions.sh"
source "$TEST_ROOT/helpers/fixtures.sh"
trap limpiar_fixture EXIT
crear_fixture

SOLICITAR="$REPO_ROOT/scripts/solicitar-issue.sh"
PROCESAR="$REPO_ROOT/scripts/procesar-cola.sh"

echo "Caso: valida la entrada y no permite inyección"
for valor in '' abc '../7' '7;id' '-1' '1 2' '1/2' '*'; do
  ejecutar_rc "$FIXTURE/salida" "$SOLICITAR" "$valor"
  afirmar_igual "$RC" 64
done
afirmar_igual "$(find "$AI_QUEUE_DIR" -maxdepth 1 -type f | wc -l)" 0

echo "Caso: crea una solicitud privada e idempotente"
umask 022
"$SOLICITAR" 42 >/dev/null
afirmar_archivo "$AI_QUEUE_DIR/issue-42.pending"
afirmar_igual "$(stat -c %a "$AI_QUEUE_DIR/issue-42.pending")" 600
ejecutar_rc "$FIXTURE/salida" "$SOLICITAR" 42
afirmar_igual "$RC" 75

echo "Caso: el bloqueo impide dos procesadores"
exec 8>"$AI_QUEUE_DIR/.procesador.lock"
flock -n 8
ejecutar_rc "$FIXTURE/salida" "$PROCESAR"
afirmar_igual "$RC" 75
afirmar_contiene "$FIXTURE/salida" "otro procesador"

echo "Caso: un issue activo o terminal tampoco se duplica"
rm -f "$AI_QUEUE_DIR/issue-42.pending"
for estado in running done failed; do
  mkdir -p "$AI_QUEUE_DIR/completadas" "$AI_QUEUE_DIR/fallidas"
  case "$estado" in
    done) ruta="$AI_QUEUE_DIR/completadas/issue-42.done" ;;
    failed) ruta="$AI_QUEUE_DIR/fallidas/issue-42.failed" ;;
    *) ruta="$AI_QUEUE_DIR/issue-42.$estado" ;;
  esac
  : >"$ruta"
  ejecutar_rc "$FIXTURE/salida" "$SOLICITAR" 42
  afirmar_igual "$RC" 75
  afirmar_no_archivo "$AI_QUEUE_DIR/issue-42.pending"
  rm -f "$ruta"
done

echo "Pruebas offline de cola superadas."
