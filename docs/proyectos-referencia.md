# Proyectos de referencia

Qué hay ya construido en el ecosistema open source, qué vale la pena copiar y qué conviene dejar pasar. Investigación de agosto de 2026.

La conclusión corta: **la arquitectura de este proyecto es correcta y coincide con lo que hace el resto del ecosistema**, pero le faltaban cuatro piezas que casi todos los proyectos maduros tienen. Las cuatro se incorporaron.

---

## Lo que se incorporó, y de dónde salió

| Pieza incorporada | Copiada de | Qué problema resuelve |
|---|---|---|
| **LiteLLM como gateway** | LiteLLM, MartinLoop, omnigent | Tope de gasto real + arregla la incompatibilidad de API (ver abajo) |
| **Git worktrees por agente** | amux, dmux, claude-squad, cyrus, vibe-tree, Composio | Los 3 agentes en paralelo sin pisarse ni clonar 3 veces |
| **`AGENTS.md`** | Estándar de la Linux Foundation, 60 000+ repos | Codex lo lee solo: las reglas del repo dejan de repetirse en cada prompt |
| **Gitleaks pre-commit** | Práctica estándar; ver dato de GitGuardian abajo | Impide que un agente commitee una clave |

Cada una tiene su ADR en [decisiones.md](decisiones.md) (ADR-010 a ADR-013) y su fase en [instalacion.md](instalacion.md).

---

## 🔴 El hallazgo que rompía la configuración

**Desde febrero de 2026, Codex CLI solo acepta `wire_api = "responses"`.** El valor `"chat"` (Chat Completions) fue eliminado. Los proveedores externos tienen que hablar la Responses API de OpenAI para conectarse a Codex directamente.

DeepSeek, Bailian y Zhipu exponen Chat Completions, no Responses. Es decir: **la configuración original de los perfiles `deepseek`, `qwen` y `glm` no habría funcionado.** Habría fallado recién en la Fase 7, después de montar toda la infraestructura.

**La solución es LiteLLM.** Expone un endpoint `/v1/responses` y hace de puente hacia `/chat/completions` de cada proveedor. Codex ve un único proveedor que habla Responses; LiteLLM traduce por detrás.

```
Antes (no funciona):
  Codex ──responses──✗── DeepSeek (solo habla chat completions)

Ahora:
  Codex ──responses──► LiteLLM ──chat──► DeepSeek / Qwen / GLM
                          │
                          └── presupuestos, fallbacks, log de costos
```

Y de paso resuelve tres cosas más que estaban pendientes:

| Pendiente que había | Cómo lo resuelve LiteLLM |
|---|---|
| El tope de gasto vivía en un `.env` que nadie hacía cumplir | Presupuesto por clave virtual, aplicado por el gateway |
| Cambiar de modelo obligaba a tocar `config.toml` | Se cambia en el YAML de LiteLLM, sin tocar Codex |
| No había registro de cuánto gastó cada agente | Registra costo por llamada y por clave |

Detalle en [ADR-010](decisiones.md#adr-010--litellm-como-gateway-de-modelos).

---

## El mapa del ecosistema

Hay más de 150 orquestadores de agentes open source publicados. Se agrupan en cinco familias, y este proyecto toca tres de ellas.

### Asistentes personales con mensajería

Donde encaja **OpenClaw**, la elección de este proyecto.

| Proyecto | Qué hace | Relevancia |
|---|---|---|
| **OpenClaw** (ex Clawdbot / Moltbot) | Asistente self-hosted con memoria persistente, multi-modelo, 10+ plataformas de mensajería (Telegram, WhatsApp, Discord, Slack, Signal, Matrix). ~15 000 estrellas | ✅ **El elegido.** Confirmado que existe y está activo |
| **Hivekeep** | Equipo de agentes self-hosted con memoria persistente; Telegram/Slack/Discord/Matrix | Alternativa más cercana a "equipo" que a "asistente" |
| **nanoclaw** | Alternativa liviana a OpenClaw; WhatsApp/Telegram/Slack/Discord/Gmail | Plan B si OpenClaw resulta pesado |
| **takopi** | Puente de Telegram que mete cada sesión de agente en un hilo del chat | 💡 **Idea copiable:** un hilo por tarea en vez de un chat plano |
| **iva** | Asistente de Telegram que convierte mensajes, voz y fotos en notas; crons y MCP | Nada que copiar aquí |

> **Sobre las estrellas:** la cifra real de OpenClaw ronda las 15 000, no 247 000 como decía el documento original. El proyecto es serio y está activo, pero conviene tener la escala correcta.

### Enjambres multi-agente

Aquí está el corazón de este diseño: planificador → ejecutores en paralelo → revisor.

| Proyecto | Qué hace | Qué copiar |
|---|---|---|
| **orc** | Framework liviano montado sobre un CLI: planificación, descomposición, worktrees y revisión | Es **exactamente esta arquitectura**. Confirma que el diseño es sensato |
| **5dive** | Agentes con nombre en un organigrama, se pasan trabajo, escalan por **Telegram**, cinco proveedores | 💡 El patrón de escalado a humano por Telegram |
| **kodo** | Cada resultado lo verifica un agente **distinto** del que lo produjo | Valida la existencia del Agente Revisor |
| **gastown** | Escala a 20–30 agentes con coordinador, seguimiento en git y *watchdogs* de salud | 💡 El watchdog: detectar un agente colgado |
| **Fusion** | Puertas de plan → revisión → ejecución, misiones jerárquicas | 💡 Puertas explícitas entre etapas |
| **tutti** | Flujos por configuración que pasan artefactos tipados entre agentes en worktrees | 💡 Artefactos tipados (el plan JSON del Planificador ya va por ahí) |

### Corredores de tareas autónomos

De aquí sale el flujo issue → PR.

| Proyecto | Qué hace | Qué copiar |
|---|---|---|
| **cyrus** | Observa Linear/GitHub/GitLab/Slack; levanta un **worktree aislado por issue**; cuatro proveedores | 💡 **Un worktree por issue.** Es lo que se adoptó |
| **open-swe** | Se dispara por comentario en Slack/Linear/GitHub; sandbox por tarea; **sale un PR en borrador** | 💡 **PR en borrador**, no listo para merge: refuerza el freno humano |
| **codex-action** | GitHub Action oficial de OpenAI, headless, tres niveles de permisos de sandbox | 💡 Correr al Revisor **también** como check de CI |
| **claude-code-action** | Action oficial de Anthropic | Ídem |
| **OpenHands** | Self-hosteable, conduce Claude Code y Codex; 68,4 % en SWE-Bench Verified | Se descartó como core, pero su sandbox es la referencia |
| **aeon** | Runner de GitHub Actions que despacha a seis agentes con puntuación de calidad | 💡 Puntuar la calidad de cada corrida |

### Bucles autónomos — de dónde vienen los frenos

Estos proyectos existen porque a alguien se le fue de las manos un bucle. Vale la pena mirarlos.

| Proyecto | Freno que implementa |
|---|---|
| **MartinLoop** | **Limita el gasto**, aplica política, verifica salida y revierte fallos dejando comprobante |
| **fractal** | Delega en subagentes acotado por **profundidad, costo y tiempo** |
| **ralph-claude-code** | Detecta cuándo el trabajo terminó, para no seguir iterando de gusto |
| **toryo** | Confirma mejoras, **revierte regresiones** automáticamente |
| **bernstein** | Verifica con tests y commitea solo si pasan |
| **Dex** | Planificación con puerta humana, revisión con múltiples revisores |

El patrón común: **límite por costo, por tiempo y por profundidad, más una condición de salida explícita.** Este proyecto tenía solo el de reintentos (`MAX_RETRIES_PER_TASK=2`); se agregaron los otros en el ADR-014.

### Aislamiento y sandbox

| Proyecto | Enfoque |
|---|---|
| **agentbox** | VM sandbox por agente con checkpoints de menos de un segundo |
| **agenttier** | Runtime de Kubernetes: un Pod por agente detrás de NetworkPolicy default-deny |
| **sandbox-agent** | API para manejar seis agentes sobre E2B/Daytona/Modal/Docker |
| **Fletch** | Sella cada agente en un clon del repo bajo Seatbelt o Docker |
| **omnigent** | Meta-harness con backends de sandbox intercambiables y política |

Para una VM personal esto es sobredimensionado. La combinación **worktree + sandbox de Codex acotado al workspace** da un aislamiento suficiente sin montar Kubernetes en casa.

---

## Git worktrees: por qué se adoptaron

Era una de las preguntas abiertas del diseño ("¿los agentes comparten un clon o cada uno el suyo?"). El ecosistema ya la respondió: **worktrees**, y no hay mucha discusión al respecto.

Un worktree da a cada agente **su propio directorio de trabajo compartiendo un solo `.git`**. Comparado con tres clones completos:

| | 3 clones | 3 worktrees |
|---|---|---|
| Espacio en disco | 3× el repo | 1× + los archivos de cada rama |
| `git fetch` | Tres veces | Una vez, todos lo ven |
| Aislamiento de archivos | Total | Total |
| Ramas cruzadas | Requiere push/pull entre clones | El Revisor las ve todas localmente |

Ese último punto es el decisivo: el Revisor puede unir las tres ramas **sin pasar por GitHub**, porque los tres worktrees comparten el mismo repositorio. Con clones separados habría que pushear y traer todo antes de poder integrar.

```bash
git worktree add ../wt-backend feat/issue-12-backend
git worktree add ../wt-tests   test/issue-12
git worktree add ../wt-docs    docs/issue-12
```

Los proyectos que lo usan: amux, dmux, claude-squad, vibe-tree, cyrus, supacode, Composio, constellagent, automaker, agentsmesh, tutti. JetBrains le dio soporte nativo en su versión 2026.1.

Automatizado en [`scripts/nueva-tarea.sh`](../scripts/nueva-tarea.sh).

---

## AGENTS.md: el archivo más barato de agregar

`AGENTS.md` es un estándar bajo la Linux Foundation, usado por más de 60 000 repos y **leído de forma nativa por Codex CLI**, Claude Code, Cursor, Aider, Copilot, Gemini CLI y Windsurf.

Sirve para poner las reglas del repositorio en un lugar que los agentes leen solos, en vez de repetirlas en cada prompt. Menos tokens por llamada y menos posibilidad de que un agente ignore una convención.

La lección de quienes lo estudiaron: **los archivos cortos y precisos rinden mejor que los largos y genéricos.** 30–50 líneas con stack, comandos, estilo y límites. Un ejemplo de código vale más que tres párrafos describiendo la convención.

Está en la raíz del repo: [`AGENTS.md`](../AGENTS.md).

---

## Gitleaks: el dato que lo justifica

Un informe de GitGuardian de marzo de 2026 midió que **los commits asistidos por IA filtran secretos a aproximadamente el doble de la tasa humana.** Claude Code, Cursor y Codex han commiteado credenciales en el último año.

Este proyecto tiene un repositorio **público** y cuatro claves de API en la máquina. La defensa es de tres capas, y ninguna cuesta trabajo:

| Capa | Herramienta | Cuándo actúa |
|---|---|---|
| 1 | Gitleaks en pre-commit | Antes de que el commit se registre |
| 2 | TruffleHog o Gitleaks en CI | Antes del merge |
| 3 | Push protection de GitHub | Del lado del servidor, último recurso |

La capa 1 es la que importa: una vez que el secreto entra al historial de git, hay que asumir que ya fue leído. Configurado en [`.pre-commit-config.yaml`](../.pre-commit-config.yaml).

---

## Lo que se miró y se dejó pasar

| Proyecto | Por qué no |
|---|---|
| **Vibe Kanban**, octomux, kandev | Interfaz Kanban de escritorio. Este proyecto se maneja desde el celular: la interfaz es Telegram |
| **agenttier**, agentbox | Kubernetes o VMs por agente. Sobredimensionado para una VM en casa |
| **loki-mode** | 41 agentes en 8 enjambres. Además su licencia es BUSL-1.1, no del todo abierta |
| **humanlayer** | Buena idea (puertas humanas) pero mayormente discontinuado |
| **OpenHands** | Sigue siendo redundante con Codex, y trae su propio sandbox pesado |
| **agent-runbook**, skillfold | Skills declarativas en YAML. Interesante si el proyecto crece; hoy suma complejidad sin ganancia |
| **Langfuse** y observabilidad dedicada | LiteLLM ya registra costo y latencia por llamada. Alcanza para una flota de cinco agentes |

---

## Ideas anotadas para más adelante

No entran ahora, pero están identificadas:

- **Hilo de Telegram por tarea** (de takopi) — cada tarea en su propio hilo, en vez de un chat plano donde todo se mezcla.
- **PR en borrador** (de open-swe) — abrir el PR como *draft* refuerza que nada se mergea solo.
- **El Revisor como check de CI** (de codex-action) — correr la revisión también en GitHub Actions, no solo en la VM.
- **Watchdog de agentes colgados** (de gastown) — detectar el agente que dejó de responder y matarlo.
- **Reversión automática de regresiones** (de toryo) — si una corrida empeora los tests, revertirla sola.

---

## Fuentes

- [awesome-agent-orchestrators](https://github.com/andyrewlee/awesome-agent-orchestrators) — el catálogo del que salió la mayor parte de este relevamiento
- [awesome-openclaw](https://github.com/SamurAIGPT/awesome-openclaw)
- [LiteLLM](https://github.com/BerriAI/litellm) · [docs `/responses`](https://docs.litellm.ai/docs/response_api) · [presupuestos](https://docs.litellm.ai/docs/proxy/provider_budget_routing)
- [Codex CLI — proveedores custom](https://codex.danielvaughan.com/2026/04/23/codex-cli-custom-model-providers-configuration-guide/)
- [OpenHands](https://www.openhands.dev/)
- [Git worktrees para agentes en paralelo](https://www.augmentcode.com/guides/git-worktrees-parallel-ai-agent-execution)
- [AGENTS.md](https://www.morphllm.com/agents-md-guide)
- [Gitleaks](https://dev.to/pickuma/gitleaks-open-source-secret-scanning-for-git-repos-in-2026-4ceb)
