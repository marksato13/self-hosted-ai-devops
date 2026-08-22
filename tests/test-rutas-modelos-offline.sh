#!/usr/bin/env bash
set -euo pipefail

TEST_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$TEST_ROOT/.." && pwd)"
source "$TEST_ROOT/helpers/assertions.sh"

# shellcheck source=scripts/lib/rutas-modelos.sh
source "$REPO_ROOT/scripts/lib/rutas-modelos.sh"

echo "Caso: conserva el orden de una cadena de rutas"
rutas=()
cargar_rutas_modelos 'combo/planner,oc/big-pickle,cx/gpt-5.6-sol' rutas
afirmar_igual "${rutas[*]}" 'combo/planner oc/big-pickle cx/gpt-5.6-sol'

echo "Caso: permite identificadores de proveedores y modelos"
rutas=()
cargar_rutas_modelos 'openrouter/qwen/qwen3-coder,ollama/qwen2.5-coder:3b' rutas
afirmar_igual "${#rutas[@]}" 2

echo "Caso: rechaza texto que no es un identificador de modelo"
if cargar_rutas_modelos 'oc/big-pickle,modelo;comando' rutas >/dev/null 2>&1; then
  fallar 'aceptó una ruta con caracteres de shell'
fi
if cargar_rutas_modelos 'oc/big-pickle, modelo' rutas >/dev/null 2>&1; then
  fallar 'aceptó una ruta con espacio'
fi

echo "Pruebas offline de rutas de modelos superadas."
