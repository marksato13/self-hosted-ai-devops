# Despliegue y topología de la flota

Esta flota es **autohospedada en control y ejecución**, no en inferencia: el
runner y las credenciales viven en tu máquina, pero Telegram, GitHub y los
modelos conectados a OmniRoute son servicios externos. Separar esas capas evita
confundir un gateway local con un modelo local.

## Componentes y responsabilidad

| Componente | Dónde corre | Responsabilidad | No debe hacer |
|---|---|---|---|
| Telegram | servicio externo | recibe órdenes y entrega avisos | ejecutar comandos del texto recibido |
| OpenClaw | contenedor Docker | valida remitente y escribe una orden cerrada en la cola | montar el repo objetivo o tener shell |
| Cola | volumen/directorio local | desacopla Telegram del trabajo y permite recuperación | aceptar contenido no validado |
| Runner `systemd` | host Linux | toma un issue, crea worktrees y controla reintentos | usar `danger-full-access` |
| Codex CLI | host Linux, sandbox | planifica o edita una subtarea en un worktree | heredar tokens de GitHub o Telegram |
| OmniRoute | contenedor Docker | catálogo, aliases `combo/*`, cuotas y fallback entre proveedores | decidir merges o guardar secretos en Git |
| Integrador | host Linux | une ramas, ejecuta Gitleaks/tests/Compose y abre PR borrador | resolver conflictos ambiguos o fusionar `main` |
| GitHub Actions | GitHub | repite la validación en un entorno limpio | sustituir la revisión humana |
| Tailscale | host Linux | acceso privado a SSH y al stage | publicar el stage mediante Funnel |

La ruta de confianza es: **Telegram → OpenClaw → cola → runner → worktree →
PR**. Las respuestas de modelos nunca cruzan directamente desde Telegram hasta
una shell.

## Routing de modelos

OmniRoute es el único gateway de la flota. Dentro de él conectá proveedores y
creá aliases `combo/*` por propósito, no por marca de modelo:

| Alias sugerido | Prioridad | Uso |
|---|---|---|
| `combo/planner` | alta calidad → económico | plan corto y JSON |
| `combo/coding` | modelo de código principal → fallback | backend y refactors |
| `combo/fast` | barato/rápido → fallback | tests, docs y clasificación |
| `combo/vision` | modelo multimodal → fallback | diseñador visual |

Cada combo debe contener solamente conexiones comprobadas. Podés conectar
Codex, Claude, Gemini, OpenRouter, Kimi, DeepSeek u Ollama si el catálogo local
los anuncia, pero una conexión visible no prueba que tenga saldo, permisos o
tool-calling compatible. Usá `scripts/verificar-rutas-modelos.sh` antes de
poner un alias en `.env`.

No encadenes gateways externos en serie por defecto (por ejemplo, Codex →
OmniRoute → OpenRouter → otro proxy). Agrega latencia, dificulta rastrear costo
y mezcla políticas de datos. OmniRoute debe ser el único punto de routing; los
demás son proveedores conectados dentro de él.

## Dónde levantarlo localmente

Para desarrollo, usá **Windows + WSL2 Ubuntu + Docker Desktop**. Cloná el
repositorio dentro del filesystem Linux (`~/self-hosted-ai-devops`), no en
`C:\`, porque los scripts, permisos y worktrees son Linux.

```text
Windows: Docker Desktop y editor
WSL2 Ubuntu: Codex CLI, gh, gitleaks, runner y repositorios Git
Docker Desktop: OmniRoute + OpenClaw + Ollama opcional
```

En local mantené siempre:

```env
AI_AUTONOMOUS_MODE=off
AI_AGENT_CONCURRENCY=1
```

Usá un bot de Telegram y un repositorio GitHub de pruebas distintos de los de
producción. Docker Desktop se pausa al cerrar sesión o suspender el PC, por lo
que el modo local sirve para validar configuración, no para operar de noche.

## Dónde levantarlo como servidor

Para operación continua, la mejor opción para esta arquitectura es una **VM
Ubuntu Server 24.04 dedicada** en tu ESXi o en un mini-PC de casa: 4 vCPU, 8 GB
de RAM y 40 GB de disco como punto inicial. Allí corren Docker, el runner de
`systemd`, Codex CLI y los repositorios; Tailscale entrega acceso remoto sin
abrir puertos en el router.

```text
VM Ubuntu Server
├── Docker: OmniRoute, OpenClaw, Ollama/stage opcionales
├── systemd --user: cola, control y reconciliación
├── Codex CLI + worktrees: host, sandbox obligatorio
├── /home/usuario/.env: permisos 600
└── Tailscale: SSH y stage privados
```

No separaría OpenClaw y el runner en servidores distintos al inicio: obliga a
exponer o sincronizar la cola, aumenta el manejo de secretos y no mejora la
capacidad de un solo repositorio. Separalos solo cuando haya varios runners,
repositorios o equipos.

Un VPS es razonable si necesitás disponibilidad fuera de casa, pero no es mi
primera elección para repositorios privados: requeriría cifrado de backups,
disco, secretos, reglas de egreso y una tailnet bien administrada. La VM local
detrás de Tailscale mantiene los worktrees y las credenciales bajo tu control.

## Orden de activación

1. Local: Docker Desktop y WSL2, con modo autónomo apagado.
2. Conectar un proveedor y crear la clave local de OmniRoute.
3. Crear y verificar aliases `combo/*`; dejar vacías las cadenas que no estén
   probadas.
4. Ejecutar el ciclo contra un issue y repositorio de prueba.
5. Migrar la misma configuración a la VM dedicada.
6. Verificar allowlist de Telegram desde otra cuenta, CI, sandbox y recuperación
   tras reinicio.
7. Solo entonces activar `AI_AUTONOMOUS_MODE=on`.
