#!/usr/bin/env bash
# Construye cadenas de rutas de OmniRoute sin interpretar texto como shell.

modelo_valido() {
  [[ "$1" =~ ^[A-Za-z0-9][A-Za-z0-9._:/-]*$ ]]
}

cargar_rutas_modelos() {
  local lista="$1" destino="$2" modelo
  local -a items=()
  local -n destino_rutas="$destino"

  IFS=',' read -r -a items <<<"$lista"
  (( ${#items[@]} > 0 )) || return 64
  destino_rutas=()
  for modelo in "${items[@]}"; do
    if ! modelo_valido "$modelo"; then
      echo "Ruta de modelo inválida: $modelo" >&2
      return 64
    fi
    destino_rutas+=("$modelo")
  done
}
