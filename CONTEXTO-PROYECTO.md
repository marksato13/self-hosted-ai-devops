# CONTEXTO DEL PROYECTO — `self-hosted-ai-devops`

> **Para qué sirve este archivo:** es el documento de traspaso. Se pega (o se referencia) en Claude Code / Codex para que cualquier agente retome el trabajo sin volver a explicar nada.
> **Última actualización:** 2026-08-05 · **Estado:** diseño cerrado, implementación no iniciada.

---

## 1. Resumen en una línea

Flota personal de agentes de IA, autohospedada en un ESXi propio, comandada desde el celular por Telegram, capaz de avanzar un repo de GitHub sola (rama → código → tests → PR), combinando un modelo caro para planificar/revisar con modelos chinos baratos para ejecutar.

**Repo destino:** https://github.com/marksato13/self-hosted-ai-devops.git — público, vacío, pendiente de inicializar.

---

## 2. Objetivo y criterios de éxito

Objetivo: mandar `"avanza el issue #12"` por Telegram y recibir de vuelta el link de un Pull Request revisado.

Se considera logrado cuando se cumplen los cuatro:

- [ ] Un mensaje de Telegram dispara trabajo real en la VM sin tocar la PC.
- [ ] Al menos tres agentes con modelos distintos producen commits en ramas separadas.
- [ ] Un agente revisor consolida, corre los tests y abre **un solo** PR.
- [ ] El costo mensual en APIs se mantiene por debajo del tope definido (ver §8).

---

## 3. Infraestructura

### Decisión: hipervisor local, no nube

Se evaluó AWS con presupuesto de $50 y se **descartó**: una GPU en AWS parte de ~$0.50/hora, lo que agota el presupuesto en días, y ya existe hardware propio ocioso.

**Elegido:** VMware ESXi 8.0 Update 3e (licencia gratuita de Broadcom, sin vCenter, tope de 8 vCPU por VM — suficiente).

### Capacidad del host (medida, no estimada)

| Recurso | Libre | Total | Uso |
|---|---|---|---|
| CPU | 8,5 GHz | 11,4 GHz | 25 % |
| RAM | 21,08 GB | 63,63 GB | 67 % |
| Disco | 258,81 GB | 825,75 GB | 69 % |

### VM a crear

| Parámetro | Valor |
|---|---|
| SO | **Ubuntu Server 24.04 LTS** — Server, no Desktop (ver §3.1) |
| vCPU / RAM / Disco | 4 / 6 GB / 30 GB |
| Red | **Bridged** (IP de la LAN) |
| Acceso remoto | Tailscale instalado en la VM |
| Snapshot | Tomar uno **antes** de instalar OpenClaw y otro con el stack ya funcionando |

**Nota clave sobre red:** Telegram funciona por *polling* (el bot consulta a los servidores de Telegram), por lo tanto **no hay que abrir ningún puerto en el router**. Tailscale cubre el SSH remoto sin exponer nada a internet.

### 3.1 Ubuntu Server, no Ubuntu Desktop

| Criterio | **Server** | Desktop |
|---|---|---|
| RAM en reposo | ~400 MB – 1 GB | ~2,5 – 4 GB solo por GNOME |
| Disco | ~5 GB | ~15 GB |
| Interfaz | Solo terminal (SSH) | Escritorio gráfico |
| Superficie de ataque | Mínima | Mayor (navegador, sesión gráfica, servicios) |

Nunca vas a mirar esta VM: se opera desde el celular por Telegram, y cuando entrás es por SSH vía Tailscale. Un escritorio al que nadie mira gastaría 2–3 de los 6 GB asignados las 24 horas, dejando sin margen a Docker y Codex — que sí lo necesitan. Además, todo lo que se instala es CLI: Docker, Tailscale, Codex CLI y git; ninguno necesita entorno gráfico.

Solo convendría Desktop si un agente tuviera que manejar un navegador con interfaz para pruebas end-to-end. No es el caso, y si llegara a serlo se resuelve con un contenedor headless.

**Versión:** 24.04 LTS (soporte hasta 2029). Se prefiere sobre 26.04 salvo que esta ya lleve meses publicada y con repos de Docker y Tailscale confirmados. En infraestructura conviene la LTS con rodaje.

---

## 4. Herramientas evaluadas

| Herramienta | Qué es | Veredicto |
|---|---|---|
| **OpenClaw** | Orquestador de agentes con integración nativa a Telegram/WhatsApp/Discord/Slack + app móvil de control, self-hosted | ✅ **Elegido — orquestador / puerta de entrada** |
| **Codex CLI** (OpenAI) | Agente de código oficial de OpenAI, ya incluido en el ChatGPT Plus/Pro del usuario. Soporta proveedores custom vía Responses API, así que se le puede apuntar a DeepSeek / Qwen / GLM (todos con tool-calling) | ✅ **Elegido — único ejecutor de código**, vía perfiles en `config.toml` |
| Aider | CLI de pair-programming, nativo de git, cambia de modelo con solo `--model`, muy liviano, sin sandbox | 🟡 **Plan B** si los perfiles de Codex resultan incómodos |
| n8n | Automatización visual drag&drop; su nodo "AI Agent" no mantiene estado entre ejecuciones | ❌ Como core. Opcional a futuro para automatizaciones periféricas (reportes, notificaciones) |
| Hermes Agent (NousResearch) | Agente generalista OSS, memoria persistente, se auto-mejora escribiendo skills, soporta 300+ modelos | ❌ Redundante con Codex multi-modelo; además no trae capa de Telegram |
| OpenHands (ex OpenDevin) | Agente autónomo con sandbox Docker propio, abre PRs nativo, integra GitHub/Jira/Slack | ❌ Más pesado (exige su propio sandbox Docker) y redundante con Codex |

> ⚠️ **Verificar antes de instalar:** los nombres y versiones de modelos manejados en este diseño (GPT-5.1, DeepSeek V4, Qwen3.5-coder, GLM-4.5-Air), la popularidad/madurez real de OpenClaw y el soporte de proveedores custom en Codex CLI vienen de la investigación previa y **no fueron revalidados en esta sesión**. Confirmar contra la documentación oficial en el momento de instalar y ajustar §5 si cambió algo.

---

## 4.1 🔴 Corrección importante tras investigar el ecosistema

**El diseño original de los perfiles de Codex no habría funcionado.** Desde febrero de 2026, Codex CLI solo acepta `wire_api = "responses"`; el valor `"chat"` fue eliminado y los proveedores externos deben hablar la Responses API. DeepSeek, Bailian y Zhipu exponen Chat Completions. Los perfiles `deepseek`, `qwen` y `glm` habrían fallado recién en la fase de instalación de Codex, con toda la infraestructura ya montada.

**Solución: LiteLLM como gateway.** Recibe `/v1/responses` de Codex y traduce a `/chat/completions` de cada proveedor. De paso resuelve el tope de gasto (lo aplica el gateway, no un `.env`), el registro de costo por agente y los *fallbacks* si un proveedor se cae.

Tres piezas más que se incorporaron del ecosistema open source:

| Pieza | De dónde | Qué resuelve |
|---|---|---|
| **Git worktrees por agente** | amux, cyrus, claude-squad, Composio | Los 3 agentes en paralelo sin pisarse; el Revisor integra local, sin pasar por GitHub |
| **`AGENTS.md`** | Estándar Linux Foundation, 60 000+ repos | Codex lo lee solo: las reglas dejan de repetirse en cada prompt |
| **Gitleaks en pre-commit** | Práctica estándar | Los commits con IA filtran secretos a ~2× la tasa humana (GitGuardian, 03/2026) |

Detalle completo en `docs/proyectos-referencia.md` y ADR-010 a ADR-014 en `docs/decisiones.md`.

---

## 5. Stack final

- **OpenClaw** — corre en Docker dentro de la VM. Escucha Telegram (token de BotFather) y la app móvil. Decide qué tarea va a qué perfil/modelo.
- **Codex CLI** — único ejecutor, con estos perfiles en `~/.codex/config.toml`:

| Perfil | Modelo | Rol | Costo |
|---|---|---|---|
| `openai` | GPT-5.1 | Planificar, decisiones complejas, revisión final | Ya pagado (ChatGPT) |
| `deepseek` | DeepSeek V4 | Código de backend | Barato |
| `qwen` | Qwen3.5-coder | Tests | Barato |
| `glm` | GLM-4.5-Air | Documentación | Gratis |

- **Git/GitHub** — Personal Access Token de alcance mínimo (o GitHub App) en la VM, para clonar, commitear, pushear y abrir PRs **solo** sobre `self-hosted-ai-devops`.

---

## 6. Flujo de trabajo

```
Telegram ──► OpenClaw ──► Planificador (GPT-5.1)
                                │  divide en subtareas
                ┌───────────────┼───────────────┐
                ▼               ▼               ▼
          Backend          Tests            Docs
        (DeepSeek V4)    (Qwen3.5)      (GLM-4.5-Air)
          rama feat/…     rama test/…    rama docs/…
                └───────────────┼───────────────┘
                                ▼
                      Revisor (GPT-5.1)
              une ramas · corre tests · valida
                   │ falla → devuelve al agente
                   ▼ ok
              1 solo Pull Request
                   ▼
      OpenClaw ──► Telegram: link del PR + resumen
                   ▼
        Usuario aprueba → merge a main
        Usuario objeta  → vuelve al Revisor con comentarios
```

Reglas del flujo:
- Cada agente trabaja **en su propia rama**; nunca escriben en `main`.
- El merge a `main` lo autoriza siempre una persona, nunca un agente.
- Si el Revisor falla dos veces sobre la misma subtarea, corta y avisa por Telegram en vez de reintentar indefinidamente.

---

## 7. Seguridad (pendiente de implementar — no omitir)

Estos puntos no estaban en la versión anterior del documento y son los que más pueden doler:

- **El bot de Telegram es público.** Cualquiera que conozca su usuario puede escribirle. Configurar en OpenClaw una *allowlist* con el `chat_id` propio y descartar todo lo demás. Sin esto, un desconocido tiene shell en la VM.
- **Secretos fuera del repo.** Todas las API keys y el token del bot van en un `.env` local o en el gestor de secretos de OpenClaw. `.gitignore` con `.env` desde el primer commit. Nunca pegar keys en este archivo ni en el README.
- **Token de GitHub de alcance mínimo:** solo el repo `self-hosted-ai-devops`, permisos de contenido y PRs. Nada de `admin` ni acceso a todos los repos.
- **Branch protection en `main`:** exigir PR y bloquear push directo, así un agente descontrolado no puede escribir en la rama principal.
- **Sandbox de Codex:** ejecutar con permisos acotados al workspace. Evitar modo full-auto sin restricciones sobre el sistema de archivos de la VM.
- **Snapshot de la VM** antes de cada cambio grande de configuración.

---

## 8. Costos y límites

- Presupuesto original de $50 destinado a nube: liberado al elegir hardware propio.
- Definir un **tope de gasto mensual y alertas de consumo en cada consola** (OpenAI, DeepSeek, Alibaba Bailian, Zhipu/Z.ai) antes de dejar agentes corriendo solos. Un bucle de reintentos puede quemar créditos de noche.
- GPT-5.1 se usa únicamente para planificar y revisar, que es donde su costo se justifica; el volumen de tokens se lo llevan los modelos baratos.

---

## 9. Estructura propuesta del repo

```
self-hosted-ai-devops/
├── README.md              # arquitectura + diagramas (derivado de este documento)
├── .gitignore             # .env, secrets/, *.key
├── .env.example           # nombres de las variables, sin valores
├── docs/
│   ├── arquitectura.md
│   ├── decisiones.md      # por qué ESXi y no AWS, por qué Codex y no OpenHands
│   └── runbook.md         # cómo levantar todo desde cero
├── infra/
│   ├── vm-esxi.md         # specs y pasos de creación de la VM
│   └── docker-compose.yml # OpenClaw
└── config/
    └── codex-config.toml.example  # los 4 perfiles, sin API keys
```

---

## 10. Estado actual

| Ítem | Estado |
|---|---|
| Repo `self-hosted-ai-devops` en GitHub | ✅ Creado y poblado |
| Contenido inicial (README, docs, infra, config) | ✅ **Hecho** — Fase 1 completa |
| VM Ubuntu en ESXi | ❌ No creada |
| Docker + OpenClaw + Codex CLI | ❌ No instalados |
| API keys (OpenAI, DeepSeek, Qwen, GLM) | ❌ Sin obtener |
| Bot de Telegram (BotFather) | ❌ Sin crear |
| Tailscale | ❌ Sin instalar |

Nota de contexto: no había conector de GitHub en el entorno de Cowork usado inicialmente, por eso el trabajo se traslada a Claude Code por CLI.

---

## 11. Plan por fases

> **Nota:** el plan por fases del repo (`docs/instalacion.md`) es más detallado: son **10 fases** con criterio verificable cada una. Lo de abajo es el resumen histórico.

**Fase 1 — Repo (se puede hacer ya, sin la VM)**
Inicializar el repo, escribir README y docs, primer commit y push.
*Listo cuando:* `git push` exitoso y el README se ve correctamente en GitHub.

**Fase 2 — VM base**
Crear la VM en ESXi, instalar Ubuntu, Docker y Tailscale.
*Listo cuando:* se entra por SSH desde el celular vía Tailscale y `docker run hello-world` funciona.

**Fase 3 — Telegram**
Crear el bot con BotFather, levantar OpenClaw, aplicar la allowlist de `chat_id`.
*Listo cuando:* un mensaje propio recibe respuesta y un mensaje de otra cuenta es ignorado.

**Fase 4 — Un agente**
Instalar Codex CLI con el perfil `openai` y darle el token de GitHub.
*Listo cuando:* por Telegram se logra que abra un PR trivial (ej. corregir una línea del README).

**Fase 5 — La flota**
Añadir los perfiles `deepseek`, `qwen` y `glm`, y el flujo planificador → paralelo → revisor.
*Listo cuando:* una tarea genera tres ramas y un solo PR consolidado.

---

## 12. Tarea inmediata

**Fase 1 — completada.** El repo está poblado con README, `docs/`, `infra/`, `config/`, `.gitignore` y `.env.example`. El clon local de trabajo está en `C:\src\self-hosted-ai-devops` (fuera del repo `AREA-DE-INFRA`, que abarca todo `C:\Users\markp`).

**Sigue la Fase 2:** crear la VM en ESXi e instalar Ubuntu Server 24.04 LTS. El paso a paso completo está en `docs/instalacion.md` del repo.

Pendiente de hacer a mano en GitHub: activar branch protection sobre `main` (§7).

---

## 13. Decisiones abiertas

- ¿OpenClaw invoca a Codex por CLI directo o hay que escribir un wrapper? → Resolver al llegar a la Fase 4.
- ¿Se usa GitHub App en vez de PAT? → El PAT alcanza para empezar; migrar si se suman más repos.
- ¿Dónde queda la memoria persistente de las tareas entre reinicios de OpenClaw? → Sin definir; revisar en la Fase 3.
- ¿Los agentes comparten un clon del repo o cada uno el suyo? → Probable uno por agente; confirmar en la Fase 5.

*(Resuelta: Ubuntu Server vs Desktop → Server, ver §3.1.)*
