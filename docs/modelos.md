# Modelos, rutas y costo

La plataforma usa OmniRoute para combinar la suscripción existente de Codex con
proveedores de capa gratuita. No mantiene saldo ni claves comerciales de
OpenAI API, DeepSeek, Alibaba, Zhipu o Kimi.

## Rutas por agente

| Agente | Perfil | Ruta OmniRoute | Costo adicional |
|---|---|---|---|
| Planificador | `planner` | `auto/coding` | USD 0; Codex Plus o fallback gratuito |
| Backend | `backend` | `auto/coding` | USD 0; Codex Plus o fallback gratuito |
| Tests | `tester` | `auto/coding:free` | USD 0 |
| Docs | `docs` | `auto/coding:free` | USD 0 |
| Revisor | `reviewer` | `auto/coding` | USD 0; Codex Plus o fallback gratuito |
| Diseñador | `designer` | `auto/multimodal:free` | USD 0 |

Los alias `auto` se resuelven dinámicamente según salud, cuota, latencia,
capacidad y tipo de tarea. El modelo concreto puede cambiar entre peticiones.

## Qué significa gratuito

OmniRoute es MIT y se ejecuta localmente. Los proveedores remotos ofrecen cuotas
gratuitas con límites y condiciones propias; no todos sus modelos son open
source. Por eso “costo adicional cero” no significa inferencia local ni servicio
ilimitado.

Reglas de esta instalación:

1. No agregar tarjetas ni saldo a proveedores de API.
2. No activar recarga automática.
3. No configurar claves comerciales en `.env`.
4. Usar rutas `:free` para trabajos de volumen.
5. Permitir Codex OAuth solo porque ya está cubierto por ChatGPT Plus.
6. Si no hay cuota gratuita, detener la tarea; nunca degradar a una ruta pagada.

## Fuente y condiciones

El catálogo [FREE_TIERS.md de OmniRoute](https://github.com/diegosouzapw/OmniRoute/blob/main/docs/reference/FREE_TIERS.md)
se actualiza periódicamente y diferencia cuotas recurrentes, créditos de alta y
proveedores sin límite publicado. También clasifica sus términos como `ok`,
`caution`, `ambiguous`, `unknown` o `avoid`.

Para esta flota personal:

- aceptar `ok`;
- evaluar manualmente `caution` antes de conectar una cuenta;
- no usar `avoid`;
- no usar wrappers de sesiones web sin API oficial;
- no compartir acceso con terceros ni revenderlo.

## Límites de la VM

La VM tiene alrededor de 7 GB de RAM. Puede ejecutar modelos locales pequeños,
pero no `qwen3-coder:30b`, que ronda 19 GB solo para el modelo cuantizado. Ollama
queda como posible fallback pequeño, no como motor principal. Para modelos
locales fuertes se recomienda ampliar la VM a 24–32 GB de RAM.

## Verificación

El gateway debe reportar salud, anunciar las rutas y completar una petición
gratuita:

```bash
./scripts/verificar.sh 5
```

La selección real se consulta en las cabeceras `X-OmniRoute-Provider`,
`X-OmniRoute-Model` y `X-OmniRoute-Response-Cost`, o en el dashboard local.

Más detalles operativos en [omniroute.md](omniroute.md).
