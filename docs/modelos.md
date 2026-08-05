# Modelos y proveedores

Qué modelo usa cada agente, de dónde sale la clave y cuánto cuesta.

> ⚠️ **Antes de configurar nada:** los nombres de modelo, endpoints y precios de este documento vienen de la investigación de diseño y **no están verificados contra las consolas oficiales**. Los proveedores renombran modelos y cambian precios seguido. Confirmá cada fila en la documentación del proveedor antes de pegar una clave, y actualizá esta tabla con lo que encuentres.

---

## 🔴 Todo pasa por LiteLLM

Codex CLI **no** habla con los proveedores directamente. Desde febrero de 2026 solo acepta la Responses API, y DeepSeek, Bailian y Zhipu exponen Chat Completions. LiteLLM traduce entre ambas.

```
Codex ──responses──► LiteLLM ──chat──► DeepSeek / Qwen / GLM
                        │
                        └── presupuestos, fallbacks, registro de costos
```

No es una comodidad: **sin LiteLLM, tres de los cinco agentes no arrancan**. Ver [ADR-010](decisiones.md#adr-010--litellm-como-gateway-de-modelos) y [`infra/litellm-config.yaml`](../infra/litellm-config.yaml).

Consecuencia práctica: los nombres de perfil de Codex son **alias** definidos en el YAML de LiteLLM. Cambiar de modelo se hace ahí, sin tocar Codex.

---

## Reparto por agente

| Agente | Alias | Modelo | Proveedor | Variable de entorno |
|---|---|---|---|---|
| Planificador | `planner` | GPT-5.1 | OpenAI | `OPENAI_API_KEY` |
| Backend | `backend` | DeepSeek V4 | DeepSeek | `DEEPSEEK_API_KEY` |
| Tests | `tester` | Qwen3.5-coder | Alibaba Bailian / DashScope | `DASHSCOPE_API_KEY` |
| Docs | `docs` | GLM-4.5-Air | Zhipu AI / Z.ai | `ZHIPU_API_KEY` |
| Revisor | `reviewer` | GPT-5.1 | OpenAI | `OPENAI_API_KEY` |

Las cuatro claves las consume **LiteLLM**. Codex solo necesita `LITELLM_MASTER_KEY`.

---

## Dónde se saca cada clave

### OpenAI — Planificador y Revisor

- Consola: https://platform.openai.com/api-keys
- El usuario **ya paga ChatGPT Plus/Pro**, que incluye Codex CLI. Verificar si el uso por API se cubre con la suscripción o se factura aparte: son dos cosas distintas y es el punto que más confunde.
- Poner un **límite de gasto mensual** en *Settings → Limits* antes de dejar agentes corriendo.

### DeepSeek — Backend

- Consola: https://platform.deepseek.com
- Modelo económico por token; es el que absorbe el grueso del volumen.
- Requiere recarga previa de saldo (prepago).

### Alibaba Bailian (DashScope) — Tests

- Consola: https://bailian.console.aliyun.com
- Suele traer una cuota gratuita inicial por modelo.
- Ojo con la **región del endpoint**: el internacional y el de China continental son distintos y las claves no son intercambiables.

### Zhipu AI / Z.ai — Docs

- Consola: https://open.bigmodel.cn (o https://z.ai)
- La variante *Air* es la gratuita o casi gratuita; es suficiente para redactar documentación.

---

## Requisito técnico común

Los cuatro proveedores deben cumplir dos condiciones para servir en este stack:

1. **API compatible con OpenAI** (endpoint `/chat/completions` o Responses API), para que Codex CLI pueda apuntarles cambiando solo la `base_url`.
2. **Soporte de *tool calling*.** Sin esto el modelo no puede leer ni escribir archivos, y por lo tanto no puede programar. Es la condición que descarta modelos que en otros aspectos serían suficientes.

Al evaluar un modelo nuevo, verificar ambas antes que cualquier otra cosa.

---

## Topes de gasto

Un agente autónomo con reintentos automáticos puede quemar créditos durante la noche sin que nadie lo note. Tres capas de defensa, en orden de importancia:

| # | Capa | Dónde | Qué tan confiable |
|---|---|---|---|
| 1 | Tope en la consola del proveedor | Web de OpenAI, DeepSeek, Bailian, Zhipu | **Absoluta** — fuera de tu código, no puede fallar |
| 2 | `max_budget` global de LiteLLM | `infra/litellm-config.yaml` | Alta — el gateway rechaza la llamada |
| 3 | Clave virtual con presupuesto por agente | LiteLLM, 5 USD cada una | Alta — aísla al agente que se desmadró |
| 4 | `MAX_RETRIES_PER_TASK`, `TASK_TIMEOUT_MINUTES` | `.env` | Media — es software propio, puede fallar |
| 5 | Alertas de consumo por correo | Consola del proveedor | No corta nada, pero te enterás a tiempo |

**La capa 1 no es opcional.** Un límite que vive solo en tu propio código no detiene nada si tu propio código tiene un bug.

La capa 3 es la más útil en la práctica: si el agente Backend entra en bucle, quema **sus** 5 USD y se detiene, sin arrastrar el presupuesto de los demás ni dejar al Revisor sin crédito. Se crean en la [Fase 5.4](instalacion.md#54--claves-virtuales-con-presupuesto-por-agente).

Consultar el gasto acumulado por agente:

```bash
curl -s http://localhost:4000/spend/logs \
  -H "Authorization: Bearer $LITELLM_MASTER_KEY" | jq
```

Tope sugerido para empezar: **20 USD/mes** en total, 5 por agente. Con el reparto previsto (85 % del volumen en modelos baratos) debería sobrar.

---

## Estimación de consumo

Referencia aproximada para una tarea típica ("avanza el issue #12"):

| Agente | Tokens estimados por tarea | Peso |
|---|---|---|
| Planificador | 5 – 15 k | Bajo |
| Backend | 50 – 200 k | **Alto** |
| Tests | 30 – 80 k | Medio |
| Docs | 10 – 30 k | Bajo |
| Revisor | 20 – 60 k | Medio |

De ahí sale la asignación de modelos: el rango alto va al proveedor barato, y el modelo caro —ya cubierto por la suscripción— se reserva para planificar y revisar.

> Estos números son estimaciones de diseño. Medí el consumo real durante la Fase 4 y reemplazá esta tabla con datos de las consolas.

---

## Si un modelo se descontinúa

Los nombres de modelo cambian con frecuencia. Para reemplazar uno:

1. Confirmá que el sustituto tiene **tool calling** y API compatible con OpenAI.
2. Actualizá `base_url` y `model` en `~/.codex/config.toml` (plantilla en [`config/codex-config.toml.example`](../config/codex-config.toml.example)).
3. Probá el perfil aislado antes de meterlo al flujo:
   ```bash
   codex --profile deepseek "escribe una función que sume dos números"
   ```
4. Actualizá la tabla de este documento y la de [agentes.md](agentes.md).

Como el ejecutor es siempre el mismo binario, cambiar de modelo no toca la arquitectura: es una línea de configuración.
