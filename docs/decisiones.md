# Decisiones de arquitectura (ADR)

Cada decisión con su contexto, la alternativa descartada y el motivo. Sirve para no volver a discutir lo mismo dentro de seis meses.

---

## ADR-001 — Hardware propio, no nube

**Contexto:** se evaluó levantar todo en AWS con un presupuesto de $50.

**Decisión:** correr en el hipervisor VMware ESXi que ya se tiene en casa.

**Por qué:**
- Una instancia con GPU en AWS parte de ~$0.50/hora. Corriendo continuo, agota los $50 en pocos días.
- El hardware propio está ocioso y sobrado: hay 8,5 GHz de CPU libres, 21 GB de RAM libres y 258 GB de disco libre.
- El presupuesto liberado se reasigna a créditos de API, que es donde el gasto sí produce valor.

**A cambio se acepta:** si se corta la luz o el internet de casa, la flota se cae. Aceptable para un proyecto personal.

---

## ADR-002 — VMware ESXi como hipervisor

**Decisión:** ESXi 8.0 Update 3e, licencia gratuita de Broadcom, sin vCenter.

**Por qué:** ya está instalado y funcionando. La licencia gratuita limita a 8 vCPU por VM, muy por encima de las 4 que se necesitan. Los snapshots permiten revertir un cambio de configuración en segundos.

**Alternativas descartadas:** Proxmox (implicaría reinstalar el host sin ganar nada), Docker sobre Windows en la PC de escritorio (obligaría a tener la PC prendida siempre).

---

## ADR-003 — OpenClaw como orquestador

**Decisión:** OpenClaw es la puerta de entrada y el repartidor de tareas.

**Por qué:** trae integración nativa con Telegram, WhatsApp, Discord y Slack, más una app móvil de control. Es self-hosted. Ninguna otra herramienta evaluada resolvía la capa de mensajería sin tener que programarla.

**Descartados:**

| Herramienta | Motivo |
|---|---|
| **n8n** | Su nodo "AI Agent" no mantiene estado entre ejecuciones. Sirve para automatizaciones lineales, no para dirigir un agente que programa. Queda como opción futura para tareas periféricas (reportes, notificaciones). |
| **Hermes Agent** (NousResearch) | Bueno —memoria persistente, se auto-mejora escribiendo skills, 300+ modelos— pero redundante con Codex multi-modelo y sin capa de Telegram propia. |
| **OpenHands** (ex OpenDevin) | Abre PRs de forma nativa, pero exige su propio sandbox Docker. Más pesado y redundante con Codex. |

---

## ADR-004 — Codex CLI como único ejecutor

**Decisión:** todo el código lo escribe Codex CLI, cambiando de modelo por perfiles en `config.toml`.

**Por qué:**
- Ya está pagado dentro de la suscripción ChatGPT Plus/Pro del usuario.
- Soporta proveedores custom vía Responses API, así que el mismo binario apunta a DeepSeek, Qwen o GLM cambiando de perfil.
- Un solo ejecutor significa un solo comportamiento que aprender, un solo archivo de configuración y un solo sitio donde depurar.

**Plan B:** **Aider**, si manejar los perfiles de Codex resulta incómodo. Es nativo de git, soporta 100+ modelos cambiando solo `--model` y es muy liviano. A cambio no tiene sandbox, lo que obliga a ser más cuidadoso con los permisos.

---

## ADR-005 — Modelo caro para pensar, modelos baratos para escribir

**Decisión:** GPT-5.1 solo planifica y revisa. DeepSeek, Qwen y GLM escriben el código, los tests y la documentación.

**Por qué:** aproximadamente el 85 % de los tokens se consumen generando código, y ahí un modelo económico rinde bien. El 15 % restante —descomponer el problema y validar el resultado— es donde un error se propaga a todo lo demás, y ahí conviene el modelo bueno. Que además ya esté pagado hace la decisión trivial.

---

## ADR-006 — Ubuntu Server, y no Ubuntu Desktop

**Decisión:** **Ubuntu Server 24.04 LTS**.

Esta es la duda que más aparece al crear la VM, así que va con detalle.

| Criterio | Ubuntu **Server** | Ubuntu **Desktop** |
|---|---|---|
| RAM en reposo | ~400 MB – 1 GB | ~2,5 – 4 GB solo por el escritorio GNOME |
| Disco de instalación | ~5 GB | ~15 GB + actualizaciones gráficas |
| Interfaz | Solo terminal (SSH) | Escritorio gráfico |
| Superficie de ataque | Mínima: SSH y poco más | Mayor: navegador, gestor de sesión, servicios de escritorio |
| Actualizaciones | Pocas, casi siempre sin reinicio | Frecuentes, con paquetes gráficos pesados |
| Rendimiento en una VM sin GPU | Ideal | El escritorio se renderiza por CPU: desperdicio puro |

**Por qué Server gana en este caso concreto:**

1. **Nunca vas a mirar esta VM.** La operas desde el celular por Telegram, y cuando entras es por SSH vía Tailscale. Un escritorio gráfico al que nadie mira consume RAM las 24 horas para nada.
2. **Esos 2–3 GB de RAM importan.** El host tiene 21 GB libres, pero se le asignaron 6 GB a la VM: gastar la mitad en un escritorio deja sin margen a Docker y a Codex, que sí lo necesitan.
3. **Menos software, menos que asegurar.** Cada servicio de escritorio es superficie de ataque en una máquina que va a tener un token de GitHub y cuatro claves de API.
4. **Todo lo que se instala es CLI:** Docker, Tailscale, Codex CLI, git. Ninguno necesita entorno gráfico.

**Cuándo habría convenido Desktop:** si algún agente necesitara controlar un navegador con interfaz para pruebas end-to-end. No es el caso; y si llegara a serlo, se resuelve con un contenedor headless (Playwright, Selenium) sin instalar un escritorio completo.

**Versión:** 24.04 LTS, con soporte hasta 2029. Se prefiere sobre 26.04 salvo que esta última ya lleve varios meses publicada y con los repositorios de Docker y Tailscale confirmados para ella. En infraestructura conviene la LTS con rodaje, no la última.

> Si te equivocaste y ya instalaste Desktop: no hace falta reinstalar. Se puede quitar el escritorio con `sudo apt purge ubuntu-desktop gnome-shell && sudo apt autoremove`, pero queda más limpio rehacer la VM desde la ISO de Server.

---

## ADR-007 — Telegram por polling, sin abrir puertos

**Decisión:** el bot consulta a los servidores de Telegram (*polling*), en lugar de exponer un *webhook*.

**Por qué:** un webhook exigiría abrir un puerto en el router, tener IP pública o un túnel, y montar un certificado TLS. El polling logra lo mismo con conexiones **salientes**, que ningún firewall doméstico bloquea. Menos piezas, menos superficie expuesta.

**A cambio se acepta:** unos segundos de latencia adicional, irrelevantes para tareas que duran minutos.

---

## ADR-008 — Tailscale para el acceso remoto

**Decisión:** Tailscale instalado en la VM para llegar por SSH desde el celular.

**Por qué:** crea una red privada entre tus dispositivos sin abrir puertos ni publicar la IP de casa. La alternativa —redirigir el puerto 22 en el router— expone SSH a todo internet y a los escaneos automáticos que vienen con eso.

---

## ADR-009 — El merge lo aprueba una persona

**Decisión:** `main` protegida; ningún agente puede mergear. Siempre hay un PR y una aprobación humana.

**Por qué:** es el freno de mano del sistema. Un agente autónomo con permiso de escritura en `main` es exactamente la clase de cosa que funciona muy bien hasta el día en que no.

---

## ADR-010 — LiteLLM como gateway de modelos

**Contexto:** el diseño original apuntaba Codex CLI directamente a cada proveedor, con un perfil por modelo y `wire_api = "chat"`.

**Eso no funciona.** Desde febrero de 2026, Codex CLI **solo acepta `wire_api = "responses"`**; el valor `"chat"` (Chat Completions) fue eliminado, y los proveedores externos deben hablar la Responses API de OpenAI para conectarse directo. DeepSeek, Bailian y Zhipu exponen Chat Completions, no Responses. Los perfiles `deepseek`, `qwen` y `glm` habrían fallado en la Fase 7, después de montar toda la infraestructura.

**Decisión:** meter **LiteLLM** entre Codex y los proveedores.

```
Antes (roto):   Codex ──responses──✗── DeepSeek (habla chat)
Ahora:          Codex ──responses──► LiteLLM ──chat──► DeepSeek / Qwen / GLM
```

LiteLLM expone `/v1/responses` y hace de puente hacia `/chat/completions`. Codex ve un proveedor único que habla su idioma.

**Lo que se gana de yapa:**

| Problema que estaba pendiente | Cómo lo resuelve |
|---|---|
| El tope de gasto vivía en un `.env` que nadie hacía cumplir | `max_budget` aplicado por el gateway — corta de verdad |
| Cambiar de modelo obligaba a editar `config.toml` | Se cambia en el YAML de LiteLLM; Codex no se entera |
| No se sabía cuánto gastó cada agente | Registra costo por llamada y por clave virtual |
| Si un proveedor se caía, la tarea moría | Cadena de *fallbacks* configurable |

**A cambio se acepta:** dos contenedores más (LiteLLM y su Postgres) y una pieza más que puede fallar. Vale la pena: sin esto, tres de los cinco agentes no arrancan.

Configuración en [`infra/litellm-config.yaml`](../infra/litellm-config.yaml).

---

## ADR-011 — Git worktrees, no clones por agente

**Contexto:** quedaba abierto si los tres agentes en paralelo comparten un clon o usan uno cada uno.

**Decisión:** **un git worktree por agente**. Cada uno tiene su directorio de trabajo, todos comparten un solo `.git`.

**Por qué:**

| | 3 clones | 3 worktrees |
|---|---|---|
| Espacio en disco | 3× el repo | 1× + archivos de cada rama |
| `git fetch` | Tres veces | Una, todos lo ven |
| Aislamiento de archivos | Total | Total |
| Que el Revisor una las ramas | Requiere pushear y traer todo | Local, inmediato |

El último punto decide: el Revisor integra las tres ramas **sin pasar por GitHub**, porque comparten repositorio.

Es además lo que hace el ecosistema — amux, dmux, claude-squad, vibe-tree, cyrus, Composio y una docena más. JetBrains le dio soporte nativo en 2026.1.

Automatizado en [`scripts/nueva-tarea.sh`](../scripts/nueva-tarea.sh) y [`scripts/limpiar-worktrees.sh`](../scripts/limpiar-worktrees.sh).

---

## ADR-012 — AGENTS.md para las reglas del repo

**Decisión:** un `AGENTS.md` en la raíz con las convenciones del repositorio.

**Por qué:** es un estándar bajo la Linux Foundation, presente en más de 60 000 repos y **leído de forma nativa por Codex CLI**, Claude Code, Cursor, Aider y Copilot. Las reglas dejan de repetirse en cada prompt: menos tokens por llamada y menos chance de que un agente ignore una convención.

**Regla de oro observada:** los archivos cortos y precisos rinden mejor que los largos y genéricos. 30–50 líneas. Un ejemplo de código vale más que tres párrafos de descripción.

---

## ADR-013 — Gitleaks en pre-commit

**Contexto:** repositorio público, cuatro claves de API y un token de GitHub en la misma máquina, y agentes autónomos commiteando sin supervisión.

**El dato que lo justifica:** un informe de GitGuardian de marzo de 2026 midió que **los commits asistidos por IA filtran secretos a aproximadamente el doble de la tasa humana**. Claude Code, Cursor y Codex han commiteado credenciales en el último año.

**Decisión:** Gitleaks como hook de pre-commit, más `no-commit-to-branch` sobre `main`.

Una vez que un secreto entra al historial de git, hay que asumir que ya fue leído: reescribir el historial no lo deshace. El hook actúa **antes** de que el commit exista.

Configurado en [`.pre-commit-config.yaml`](../.pre-commit-config.yaml).

---

## ADR-014 — Tres frenos, no uno

**Contexto:** el diseño tenía un solo límite, `MAX_RETRIES_PER_TASK=2`.

**Decisión:** tres límites independientes, siguiendo lo que hacen los proyectos de bucles autónomos (MartinLoop acota gasto, fractal acota profundidad/costo/tiempo, ralph-claude-code detecta la condición de salida):

| Freno | Dónde | Qué corta |
|---|---|---|
| `MAX_RETRIES_PER_TASK=2` | `.env` | El agente que reintenta en círculos |
| `TASK_TIMEOUT_MINUTES=30` | `.env` | El agente colgado que no reintenta ni termina |
| `max_budget: 20` | `litellm-config.yaml` | El gasto, pase lo que pase |

**Por qué tres:** cada uno atrapa un modo de falla distinto. Los reintentos no detectan un proceso colgado; el timeout no detecta un agente que gasta rápido y termina; el presupuesto no evita perder una noche de trabajo por un proceso trabado. El presupuesto es el único que se aplica fuera de nuestro propio código — por eso es el que de verdad protege.

---

## ADR-015 — El bucle visual se corta con accesibilidad, no con gusto

**Contexto:** los agentes escribían interfaces sin verlas nunca. Un test verde no dice nada sobre un botón que en móvil queda cortado. Hacía falta un bucle de «mirar y corregir», pero un bucle necesita una **condición de salida**.

**El problema:** «¿está lindo?» no tiene respuesta verificable. Un modelo al que se le pide mejorar un diseño siempre encuentra qué cambiar, aunque no haga falta. Ese es el camino directo a un proceso que reescribe el CSS cada noche y quema el presupuesto sin que nadie se lo pida.

**Decisión:** la puerta automática del bucle son dos números y nada más:

| Criterio | Medido por | Es opinable |
|---|---|---|
| Hallazgos de accesibilidad (WCAG 2 AA) | axe-core | No |
| Píxeles cambiados respecto de la base | pixelmatch | No |

Si los hallazgos de axe **no bajan**, el bucle se detiene. Si **suben**, se revierte al punto de retorno. Todo lo demás —jerarquía visual, ritmo, criterio— se le manda al humano como imagen por Telegram.

Además, el Diseñador recibe una **lista cerrada de cinco cosas que revisar** (desbordes, contraste, áreas táctiles, espaciados, grilla), no un «mejorá el diseño».

**Consecuencia:** el bucle mejora cosas medibles y admite que el resto no lo puede juzgar. Es menos ambicioso que «un agente que diseña» y por eso termina.

---

## ADR-016 — Las imágenes por Telegram, WhatsApp como aviso

**Contexto:** la idea original era recibir el informe visual por WhatsApp.

**Decisión:** las imágenes van por **Telegram**. WhatsApp queda opcional (`WHATSAPP_MODO`), y si se usa, con un **número secundario**.

**Por qué:**

| Canal | Imágenes | Traba real |
|---|---|---|
| Telegram | `sendPhoto`, álbumes de 10 | Ninguna. Ya está en el stack |
| WhatsApp Cloud API (oficial) | Sí, subiendo el archivo | **Ventana de 24 h**: fuera de ella hace falta una plantilla aprobada, y una plantilla no lleva una captura arbitraria |
| Puente no oficial (número por QR) | Sí | Viola los términos de servicio; el número puede terminar baneado |

La ventana de 24 horas es la que decide: un informe que sale a las 3 de la mañana, dos días después del último mensaje, **no llega**. Un canal de notificación que a veces no notifica no sirve como canal principal.

**Consecuencia:** un canal menos «natural» para el usuario, a cambio de que el informe llegue siempre. `scripts/reportar.sh` soporta los tres modos: la decisión se puede revisar sin tocar el resto.

---

## ADR-017 — El stage va a la tailnet, no a internet

**Contexto:** para revisar el diseño desde el celular hace falta abrir el sitio en algún lado.

**Decisión:** `tailscale serve` — URL HTTPS visible solo desde los dispositivos de la tailnet. **No** `tailscale funnel`, que la publicaría a internet entero.

**Por qué:** un stage muestra trabajo a medio hacer, generado por un agente y no revisado por nadie. Puede tener claves de prueba en el HTML, endpoints internos o un formulario que escribe en una base real. Publicarlo al mundo por comodidad es la clase de decisión que se lamenta después.

Es además coherente con [ADR-007](#adr-007--telegram-por-polling-sin-abrir-puertos): todo el tráfico del sistema es saliente y no hay un solo puerto redirigido en el router.

**Consecuencia:** para mostrarle el stage a otra persona hay que prender `funnel` deliberadamente para esa sesión y apagarlo. Un paso más, a propósito.

---

## ADR-018 — Un agente Diseñador aparte, y no el Revisor con ojos

**Contexto:** el Revisor ya usa un modelo caro y capaz. Podría mirar las capturas él mismo.

**Decisión:** un sexto agente, `designer`, con su propio modelo de visión barato y su propia clave virtual de 5 USD.

**Por qué:**

1. **Costo.** Nueve imágenes por vuelta, en un modelo caro, son la parte más cara de todo el ciclo. La misma lógica de [ADR-005](#adr-005--modelo-caro-para-pensar-modelos-baratos-para-escribir): el volumen va al modelo barato.
2. **Presupuesto aislado.** Si el bucle visual se descontrola, quema sus 5 USD y se detiene sin tocar el presupuesto del Revisor, que es quien abre los PRs.
3. **Tarea distinta.** El Revisor integra ramas, corre gitleaks y decide si se abre un PR. El Diseñador mira píxeles contra una lista de cinco puntos. Juntarlos hace un prompt largo que cumple peor las dos cosas.

**Consecuencia:** un modelo más que mantener y verificar. El requisito es que **acepte imágenes de entrada** — la tarea T057 lo comprueba explícitamente, porque un modelo de solo texto falla acá de forma silenciosa y confusa.

---

## ADR-019 — OmniRoute evaluado, LiteLLM se queda

**Contexto:** [OmniRoute](https://github.com/diegosouzapw/OmniRoute) es un gateway MIT que ocupa **exactamente el mismo lugar** que LiteLLM: un endpoint compatible con OpenAI, con enrutado, fallbacks y presupuestos. No es un complemento, es un reemplazo. Y trae tres cosas que a este proyecto le sirven de verdad: expone Responses API en `/v1` (el requisito de [ADR-010](#adr-010--litellm-como-gateway-de-modelos)), trae decenas de proveedores con capa gratuita ya cableados, y comprime las salidas de herramientas.

**Decisión:** **no se adopta por ahora.** LiteLLM sigue siendo el gateway. Se revisa después de que el sistema haya corrido estable, no antes.

**Por qué:**

| Motivo | Detalle |
|---|---|
| **Edad contra rol** | Repo creado el 13-feb-2026: seis meses y ~6.200 commits. Todo el tráfico de la flota pasa por el gateway, de noche y sin nadie mirando. En el camino crítico, aburrido es una virtud |
| **Bus factor** | 3.806 commits del autor principal; el siguiente contribuidor tiene 216 |
| **La compresión es un modo de falla silencioso** | Comprimir 89 % de la salida de herramientas es excelente para un chat. El Backend lee archivos y aplica parches: un contexto con pérdida lo degrada **sin dar error**, igual que los casos de T054 y T057 |
| **Los tiers gratis traen su letra chica** | El propio proyecto publica una tabla de ToS donde varios proveedores **prohíben explícitamente el uso vía proxy**. Una cuenta cortada a mitad de una corrida nocturna es una tarea fallada |
| **Altura** | La configuración actual son 40 líneas de YAML que se entienden enteras. Lo otro es Next.js + SQLite + Redis + Electron + modelos ONNX |

El «TLS fingerprint stealth» (JA3/JA4) es una función para evadir la detección de bots del proveedor. Está documentada y es opcional, pero no es algo para dejar corriendo desatendido contra cuentas que importan.

**Lo que sí se toma:** su [`docs/reference/FREE_TIERS.md`](https://github.com/diegosouzapw/OmniRoute/blob/main/docs/reference/FREE_TIERS.md) es un catálogo re-auditado de qué proveedor tiene capa gratuita y qué dice su ToS. Responde la advertencia que abre [modelos.md](modelos.md).

**Cómo se revierte esta decisión** (si en la Fase 12 conviene): OmniRoute **detrás** de LiteLLM, como un proveedor más, no en lugar de él —

```yaml
  - model_name: docs
    litellm_params:
      model: openai/glm-4.5-air
      api_base: http://omniroute:20128/v1   # ← en vez de la consola del proveedor
      api_key: os.environ/OMNIROUTE_KEY
```

Codex le sigue hablando a LiteLLM, los presupuestos y fallbacks no se tocan, y la prueba se hace en `docs`, que es el agente de menor riesgo. Si funciona, sube a `tester`. Si no, es una línea que se borra.

**Consecuencia:** se paga la API en lugar de usar capas gratuitas que podrían salir 0. Es el precio de que el centro del sistema sea la parte más aburrida.

---

## ADR-020 — Cola local entre OpenClaw y el runner

**Contexto:** OpenClaw corre en Docker y Codex en el host. Montar el socket de
Docker, el token de GitHub y todas las claves dentro del gateway convertiría
una vulnerabilidad del canal de mensajería en control total de la VM.

**Decisión:** OpenClaw solo escribe solicitudes numéricas en una cola montada.
Un servicio `systemd` del host valida y procesa la cola con bloqueo exclusivo.

**Consecuencia:** existe una pieza adicional, pero el contenedor no recibe los
secretos del runner. Cada solicitud deja estado auditable y puede recuperarse.

---

## ADR-021 — La VM existente conserva Ubuntu 26.04

**Contexto:** el diseño prefería Ubuntu Server 24.04, pero la VM disponible ya
ejecuta Ubuntu 26.04 sobre VMware. En ella se verificaron Node 22, Codex CLI,
Docker 29 con Compose y Tailscale. Reinstalar no aporta aislamiento adicional y
sí destruiría una base funcional.

**Decisión:** conservar Ubuntu 26.04 para esta instalación y aceptar ambas LTS
en `scripts/verificar.sh`. La documentación nueva no debe asumir que todas las
instalaciones usan la misma versión.

**Consecuencia:** cualquier instrucción dependiente de paquetes debe probarse
en esta VM antes de marcarla como completada. La compatibilidad comprobada no
convierte 26.04 en requisito para otras instalaciones.

---

## ADR-022 — OmniRoute reemplaza a LiteLLM

**Contexto:** el requisito definitivo es no pagar APIs adicionales. La VM tiene
7 GB de RAM, insuficientes para ejecutar localmente modelos de programación de
30B competitivos. ChatGPT Plus cubre Codex CLI, pero no OpenAI API.

**Decisión:** OmniRoute reemplaza a LiteLLM y PostgreSQL. Codex se conecta por
OAuth usando la suscripción existente; los perfiles de volumen usan rutas
`auto/*:free`. Se eliminan de `.env` las claves comerciales.

**Controles:** imagen fijada por digest, variante Docker sin navegador, puerto
loopback, acceso por Tailscale Serve, proceso sin root ni capabilities,
credenciales cifradas, concurrencia limitada y proveedores `avoid` excluidos.
Las funciones MITM y los proveedores basados en cookies web no se habilitan.

**Consecuencia:** no hay costo variable, pero tampoco garantía de capacidad.
Las cuotas y modelos pueden cambiar y algunos proveedores son servicios
propietarios aunque OmniRoute sea MIT. Si no queda cuota, el trabajo se detiene.
Esta decisión **reemplaza ADR-010 y ADR-019** para la instalación actual.

---

## ADR-023 — Runner reconciliado y aprobación humana en dos fases

**Contexto:** una cola despertada solamente por eventos puede perder trabajo
después de un reinicio. Además, una orden breve como «aprueba» puede referirse
a otro PR, llegar tarde o ejecutarse después de que cambió el commit.

**Decisión:** el runner usa estado atómico por issue, historial de eventos,
bloqueo exclusivo, reintentos limitados y dos disparadores systemd: un `.path`
para baja latencia y un `.timer` para reconciliación. Procesa una tarea por
invocación, recupera `.running` huérfanos y admite una pausa cooperativa.

El merge conserva intervención humana y requiere dos fases: `aprobar PR N`
produce un resumen y un código efímero; `confirmar CÓDIGO` solo es válido para
el mismo `chat_id`, PR y SHA, con CI verde comprobada nuevamente. Cambiar el
SHA invalida la aprobación.

**Consecuencia:** reiniciar la VM o perder un evento no pierde una solicitud y
un mensaje ambiguo no basta para fusionar. Hay más estado operativo que
respaldar y observar en `${AI_STATE_DIR}`. La capa Telegram se considera
pendiente hasta superar las pruebas de extremo a extremo de
[ciclo-autonomo.md](ciclo-autonomo.md).

---

## ADR-024 — Orden de modelos por rol: gratis primero, Codex al final

**Contexto:** `scripts/ejecutar-issue.sh` fijaba por defecto los cuatro roles
(planificador, backend, tests, docs) a variantes de Codex (`cx/gpt-5.6-sol`,
`cx/gpt-5.6-terra`, `cx/gpt-5.5`). Esto contradice el diseño original — un
modelo caro solo para planificar/revisar, modelos chinos baratos o gratuitos
para ejecutar — y además dejaba a los cuatro roles sin trabajo apenas se
agotaba la cuota de la cuenta ChatGPT/Codex, algo confirmado en la práctica
el 2026-08-08: el issue #4 falló dos veces con `429` porque el planificador y
los tres agentes dependían todos, en el fondo, de la misma suscripción.

Al intentar usar Kimi/DeepSeek pagos como alternativa se encontró que ninguno
está disponible ahora mismo por motivos ajenos al código: la cuenta de
Moonshot/Kimi conectada a OmniRoute está **suspendida por falta de saldo**, y
DeepSeek pago **no tiene credenciales cargadas** pese a lo que decía
`modelos.md`. Ambos requieren una acción humana (recargar saldo, cargar la
clave) que este ADR no resuelve.

**Decisión:** los cuatro roles prueban, en orden, `oc/big-pickle` →
`oc/deepseek-v4-flash-free` → una variante de Codex como último recurso.
Backend, tests y docs ahora tienen el mismo mecanismo de reintento entre
modelos ante `429` que ya tenía el planificador (antes solo reportaban el
fallo sin probar una alternativa). El motivo del fallo final (límite de
proveedor vs. fallo real de código/pruebas) se registra en
`${AI_STATE_DIR}/issues/<N>/<agente>.motivo` para no confundir un `429` de
un modelo anterior con el fallo real de otro.

Cada tramo se puede sobrescribir con `CODEX_<ROL>_MODEL`,
`CODEX_<ROL>_FALLBACK_MODEL` y `CODEX_<ROL>_LAST_RESORT_MODEL`.

**Consecuencia:** la flota deja de depender de la cuota de ChatGPT/Codex para
avanzar issues; solo la usa si las rutas gratuitas fallan de verdad. La ruta
`oc/deepseek-v4-flash-free` tiene un bug de compatibilidad conocido con
sesiones largas de tool-calling (`400 Duplicate value for 'tool_call_id'`,
ver ESTADO.md 2026-08-08) — no se puso primera en el orden por eso. Cuando se
recargue Kimi o se cargue la clave de DeepSeek pago, conviene agregarlos como
`_LAST_RESORT_MODEL` explícito por rol, nunca como reemplazo silencioso de
la ruta gratuita (regla 5 de [modelos.md](modelos.md)).

---

## ADR-025 — Gemini gratuito y Ollama local agregados a OmniRoute

**Contexto:** tras ADR-024, el bug de `tool_call_id` duplicado de la familia
`oc/*` (proxy "opencode") seguía bloqueando issue #4 en sesiones con varias
llamadas a herramientas. Se buscó una ruta gratuita alternativa que no
dependiera de esa capa de traducción específica.

**Gemini (Google AI Studio):** se conectó una clave gratuita real por la API
administrativa de OmniRoute (`POST /api/providers`, `provider:"gemini"`,
`authType:"apikey"`) — no existe UI-only, es una API real y scriptable.
Hallazgos: `gemini-2.5-flash` está deprecado para cuentas nuevas (404);
`gemini-3.6-flash` (preview) tiene cuota gratuita casi nula (429 al primer
uso real); `gemini-2.0-flash-001` funciona pero con límite de peticiones por
minuto estricto (429 con cooldown de ~60s bajo uso rápido de pruebas). Usable
como una ruta más en la cadena, no como reemplazo confiable de las gratuitas
existentes.

**Ollama local (`qwen2.5-coder:3b`):** instalado sin `sudo` (el instalador
oficial requiere una TTY para la contraseña, no disponible en este canal) y
corrido como contenedor Docker (`ollama/ollama`) en la red `infra_default`,
para que OmniRoute lo alcance por nombre de contenedor (`http://ollama:11434`)
sin cruzar el firewall del host (`ufw` bloqueaba el puerto en el host — mismo
problema de TTY para `sudo`). Se conectó a OmniRoute como `provider:"openai"`
con `providerSpecificData.baseUrl` apuntando al Ollama local — OmniRoute no
tiene un tipo de proveedor `ollama` nativo, pero acepta cualquier endpoint
compatible con la API de OpenAI bajo el tipo `openai`.

Verificado con la misma prueba de varias llamadas a herramientas que las demás
rutas: **el tool-calling no funciona** — el modelo escribe un JSON con forma
de llamada a herramienta como texto plano en vez de invocar la herramienta de
verdad. Sin pedirle herramientas (JSON directo desde texto), responde
correctamente. Además es lento en CPU (sin GPU en este host: VMware SVGA
únicamente): ~25 tokens/seg solo para procesar el prompt. Usa ~2.2 GB de RAM
cargado, en un host de 7.2 GB compartido con OmniRoute, OpenClaw y el stack de
NinjaSec — la RAM disponible bajó a ~300 MB libres con el modelo cargado
durante las pruebas.

**Decisión:** ninguna de las dos rutas se agrega al fallback automático de
`ejecutar-issue.sh`. Gemini por sus límites de minuto impredecibles bajo uso
real; Ollama local porque no sirve para los roles que necesitan tool-calling
(backend, tests, docs) y compite por una RAM ya ajustada. Quedan disponibles
como override explícito y consciente por tarea:

```bash
CODEX_PLANNER_MODEL=gemini/gemini-2.0-flash-001 ./scripts/ejecutar-issue.sh N
CODEX_PLANNER_MODEL=openai/qwen2.5-coder:3b ./scripts/ejecutar-issue.sh N   # solo planificador, sin exploración de archivos
```

**Consecuencia:** el catálogo de OmniRoute pasó de 3 a 5 conexiones
(`deepseek`, `moonshot`, `codex`, `gemini`, `openai`→ollama). El contenedor
`ollama` corre con `restart: unless-stopped` pero **no** forma parte de
`infra/docker-compose.yml` todavía — quedó creado a mano con `docker run`,
pendiente de incorporar al compose si se decide mantenerlo. Si se reinicia el
host, el contenedor `ollama` vuelve solo (policy `unless-stopped`), pero la
conexión en OmniRoute y el registro en `docker-compose.yml` no están
sincronizados — revisar antes de asumir que sobrevive un `docker compose down`.

---

## Decisiones todavía abiertas

| Pregunta | Estado |
|---|---|
| ¿OpenClaw invoca Codex por CLI directo o hace falta un wrapper? | Resuelta: cola local y runner del host, ADR-020 |
| ¿PAT o GitHub App? | El PAT alcanza para empezar; migrar si se suman más repos |
| ¿Dónde persiste la memoria de tareas de OpenClaw? | Verificar en la Fase 6 |
| ¿Conviene un hilo de Telegram por tarea, como hace takopi? | Evaluar cuando haya varias tareas concurrentes |
| ¿Correr al Revisor también como check de CI, con codex-action? | Después de la Fase 9 |
| ¿Vale la pena OmniRoute? | Resuelta: reemplaza LiteLLM, ADR-022 |

*(Resuelta: ¿clones o worktrees? → worktrees, ADR-011.)*
