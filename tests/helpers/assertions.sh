#!/usr/bin/env bash

fallar() {
  echo "FALLA: $*" >&2
  return 1
}

afirmar_igual() {
  [[ "$1" == "$2" ]] || fallar "esperado '$2', obtenido '$1'"
}

afirmar_archivo() {
  [[ -f "$1" ]] || fallar "no existe el archivo $1"
}

afirmar_no_archivo() {
  [[ ! -e "$1" ]] || fallar "no debía existir $1"
}

afirmar_contiene() {
  grep -Fq -- "$2" "$1" || fallar "$1 no contiene '$2'"
}

afirmar_no_contiene() {
  if grep -Fq -- "$2" "$1"; then
    fallar "$1 contiene material prohibido '$2'"
  fi
}

ejecutar_rc() {
  local salida="$1"; shift
  set +e
  "$@" >"$salida" 2>&1
  RC=$?
  set -e
}
