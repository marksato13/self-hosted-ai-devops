# Modelos, rutas y costo

La plataforma usa OmniRoute para combinar la suscripción existente de Codex,
proveedores gratuitos y dos conexiones comerciales opcionales. Al 7 de agosto
de 2026 están registradas Codex OAuth, Kimi/Moonshot API y DeepSeek API. Las
credenciales permanecen cifradas en OmniRoute y nunca se documentan.

## Catálogo elegido para desarrollo

| Prioridad | Modelo o ruta | Uso | Estado verificado | Costo adicional |
|---|---|---|---|---|
| 1 | `cx/gpt-5.6-sol` | Implementación y revisión exigente | Codex OAuth activo; prueba correcta | Cubierto por ChatGPT Plus; sujeto a sus límites |
| 2 | `aug/sonnet5-high` | Arquitectura, implementación y revisión | Anunciado por el catálogo; falta conexión/prueba de Auggie | Desconocido hasta revisar el plan del proveedor |
| 3 | `aug/sonnet5-500k` | Contextos excepcionalmente grandes | Anunciado por el catálogo; falta conexión/prueba de Auggie | Desconocido hasta revisar el plan del proveedor |
| 4 | `oc/big-pickle` | Desarrollo gratuito y fallback | OpenCode Free probado | USD 0 según la ruta gratuita |
| 5 | `oc/deepseek-v4-flash-free` | Desarrollo gratuito | Anunciado por OpenCode Free; pendiente de prueba individual | USD 0 según la ruta gratuita |
| 6 | `deepseek/deepseek-v4-pro` | Código y razonamiento, solo bajo petición | Conexión activa; no se hizo prueba pagada | API de pago |
| 7 | Kimi/Moonshot | Contexto largo y alternativa de código | Conexión activa; modelo exacto y prueba pendientes | API de pago |

“Sonnet 5” significa los identificadores que anuncia esta instalación de
OmniRoute bajo el proveedor Auggie. Que un modelo aparezca en `/v1/models` no
demuestra que exista una cuenta habilitada ni que pueda usarse gratis. No se
incorpora al fallback automático hasta completar una prueba y revisar costos.

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

1. No activar recarga automática.
2. No guardar claves comerciales en `.env`, Markdown, scripts ni Git; se
   introducen directamente en OmniRoute.
3. Usar rutas `:free` para trabajos de volumen.
4. Permitir Codex OAuth solo porque ya está cubierto por ChatGPT Plus.
5. Kimi y DeepSeek se invocan por nombre explícito y solo con autorización de
   costo; no deben ser fallback de una ruta marcada como gratuita.
6. Si no hay cuota gratuita, detener la tarea; nunca degradar silenciosamente a
   una ruta pagada.
7. Revisar el gasto en las consolas de Kimi y DeepSeek y fijar límites cuando el
   proveedor los permita.

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
