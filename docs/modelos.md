# Modelos, rutas y costo

La plataforma usa OmniRoute para combinar la suscripción existente de Codex,
proveedores gratuitos y dos conexiones comerciales opcionales. Al 7 de agosto
de 2026 están registradas Codex OAuth, Kimi/Moonshot API y DeepSeek API. Las
credenciales permanecen cifradas en OmniRoute y nunca se documentan.

## Catálogo elegido para desarrollo

| Prioridad | Modelo o ruta | Uso | Estado verificado al 2026-08-08 | Costo adicional |
|---|---|---|---|---|
| 1 | `oc/big-pickle` | Ejecución por defecto de los cuatro roles | **Probado**; **bug conocido** de tool-calling (`400 Duplicate value for 'tool_call_id'`) — puede aparecer temprano (mensaje 5) o tarde, no es exclusivo de sesiones largas, ver ADR-024/ADR-026 | USD 0 |
| 2 | `oc/deepseek-v4-flash-free` | Fallback gratuito si `big-pickle` se satura | Mismo bug de `tool_call_id` que `big-pickle` — no es específico de un modelo, es de la capa `opencode` de OmniRoute | USD 0 |
| 3 | `cx/gpt-5.6-sol` / `-terra` / `5.5` | Último recurso si ambas rutas gratis fallan, o forzado a mano cuando `oc/*` rompe con el bug de `tool_call_id` | Codex OAuth activo y **funcionando** (verificado 2026-08-08 21:56 — la cuota volvió antes del 12/08 anunciado). Ver ADR-026: un `429` en `cx/*` puede ser el límite de conexiones de OmniRoute, no la cuota real — revisar `docker logs omniroute` antes de asumir cuota agotada | Cubierto por ChatGPT Plus; sujeto a sus límites |
| 4 | `aug/sonnet5-high` / `aug/sonnet5-500k` | Arquitectura o contexto excepcionalmente grande | Anunciado por el catálogo; falta conexión/prueba de Auggie | Desconocido hasta revisar el plan del proveedor |
| 5 | `deepseek/deepseek-v4-pro` | Código y razonamiento, solo bajo petición | **Sin credenciales activas en OmniRoute** — `404 No active credentials for provider: deepseek` pese a lo que decía este documento antes | API de pago, hoy inutilizable hasta cargar la clave |
| 6 | `moonshot/kimi-k2.7-code` / `kimi-k2.6` | Contexto largo y alternativa de código | Conexión activa, pero **cuenta suspendida por falta de saldo** (`account ... is suspended due to insufficient balance`) | API de pago, hoy inutilizable hasta recargar |

“Sonnet 5” significa los identificadores que anuncia esta instalación de
OmniRoute bajo el proveedor Auggie. Que un modelo aparezca en `/v1/models` no
demuestra que exista una cuenta habilitada ni que pueda usarse gratis. No se
incorpora al fallback automático hasta completar una prueba y revisar costos.

Prioridades 5 y 6 requieren acción humana fuera de este repositorio —
recargar saldo en la consola de Moonshot, cargar una clave de DeepSeek en
OmniRoute — antes de poder usarse. Mientras tanto no forman parte de ningún
fallback automático (regla 5 más abajo).

## Rutas por agente

`scripts/ejecutar-issue.sh` decide el modelo real de cada rol — el perfil de
`~/.codex/*.config.toml` solo define el valor por defecto si se invoca a
mano. Ver **[ADR-024](decisiones.md#adr-024--orden-de-modelos-por-rol-gratis-primero-codex-al-final)**.

| Agente | Perfil | Orden real (variable de override) | Costo adicional |
|---|---|---|---|
| Planificador | `planner` | `oc/big-pickle` → `oc/deepseek-v4-flash-free` → `cx/gpt-5.6-sol` (`CODEX_PLANNER_MODEL`/`_FALLBACK_MODEL`/`_LAST_RESORT_MODEL`) | USD 0 salvo agotar ambas rutas gratis |
| Backend | `backend` | igual orden (`CODEX_BACKEND_*`) | USD 0 salvo agotar ambas rutas gratis |
| Tests | `tester` | igual orden, último recurso `cx/gpt-5.6-terra` (`CODEX_TESTS_*`) | USD 0 salvo agotar ambas rutas gratis |
| Docs | `docs` | igual orden, último recurso `cx/gpt-5.5` (`CODEX_DOCS_*`) | USD 0 salvo agotar ambas rutas gratis |
| Revisor | `reviewer` | perfil `auto/coding` (sin override propio todavía) | USD 0; Codex Plus o fallback gratuito |
| Diseñador | `designer` | perfil `auto/multimodal:free` | USD 0 |

Cada rol prueba primero la ruta gratuita; si responde `429`, pasa a la
siguiente de la lista. Un fallo que no sea `429` (código roto, prueba que no
pasa) corta el intento ahí — no se enmascara probando otro modelo.

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
