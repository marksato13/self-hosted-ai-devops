# Manual de uso

Este es el punto de entrada para **usar** la flota, no para instalarla. Si
todavía no está montada, empezá por [docs/arranque.md](arranque.md) o
[docs/instalacion.md](instalacion.md). Si ya está corriendo y solo querés
saber qué escribirle al bot, seguí acá.

Está escrito para una sola persona operando todo desde Telegram, en el
celular, sin abrir una terminal.

## 1. Qué hace este sistema, en concreto

Vos mantenés un repositorio de trabajo (hoy: **NinjaSec Platform**, privado)
con issues en GitHub. Cuando un issue está listo para que lo tome la flota, le
agregás la etiqueta `agente:lista`. A partir de ahí:

1. Nexo (el bot) detecta el issue y lo reparte entre tres agentes —
   backend, tests y docs — cada uno en su propia rama y su propio worktree.
2. Los agentes escriben código real, corren pruebas y commitean.
3. Un paso de integración une las tres ramas, corre gitleaks y abre **un
   solo Pull Request** en borrador contra `main`.
4. Nexo te avisa por Telegram con el link y el estado del CI.
5. Vos decidís: aprobás uno con `/a N`, o el lote completo con `/todo`.
   Cada aprobación pide un código de confirmación de un solo uso.
6. Nexo vuelve a validar CI y SHA, fusiona, y sigue con el próximo issue
   elegible — sin que hagas nada más.

Ejemplo real de este repositorio: el issue #2 de NinjaSec Platform (esquema
Alembic) pasó por los pasos 1 a 4 de forma autónoma y terminó en el PR #3,
mergeado el 2026-08-07. Es el comportamiento esperado, no una demo — pero la
confirmación de que la aprobación específicamente se disparó desde Telegram
con `/a` y `/c` (paso 5-6, tarea T044) todavía no está verificada de punta a
punta; ver [ESTADO.md](../ESTADO.md).

Lo que la flota **nunca** hace sola: escribir en `main` directamente,
fusionar sin tu confirmación, gastar en una API paga sin autorización
explícita, ni ejecutar texto libre como comandos de sistema. Ver la lista
completa en [telegram.md §6](telegram.md#6-qué-significa-aprobar-todo-y-qué-no).

## 2. Primeros pasos

Escribile al bot desde la cuenta de `TELEGRAM_ALLOWED_CHAT_IDS`:

```text
/ayuda
/estado
```

Si otra cuenta le escribe, no debe responder nada — esa prueba
(`docs/telegram.md §2`) es obligatoria después de tocar el bot, la
allowlist o OpenClaw, y antes de confiar en el modo autónomo.

## 3. Todos los comandos

| Comando | Atajo | Qué hace |
|---|---|---|
| `/flota estado` | `/estado` | Flota, tarea activa, cola, PR y aprobación pendiente |
| `/flota agentes` | `/agentes`, `/trabajo` | Qué agente trabaja, en qué fase, qué worktree |
| — | `/salud` | Estado de OpenClaw, OmniRoute, NinjaSec y dependencias |
| `/flota errores [N]` | `/error [N]` | Fallos recientes, sin exponer logs |
| `/flota siguiente` | `/sig` | Encola el próximo issue con `agente:lista` |
| `/flota issue N` | `/i N` | Encola específicamente el issue N |
| `/aprobar N` | `/a N` | Valida el PR N y pide un código de confirmación |
| `/aprobar_todo` | `/todo` | Prepara el lote de PR aprobables y pide un código |
| `/confirmar CODIGO` | `/c CODIGO` | Ejecuta la aprobación (individual o lote) ligada a ese código |
| `/rechazar N` | — | Rechaza/cierra el PR de integración N |
| `/flota detener` | `/pausa` | Deja de admitir tareas nuevas; la activa termina sola |
| `/flota reanudar` | `/seguir` | Levanta la pausa |
| `/flota ayuda` | `/ayuda` | Este mismo resumen, desde el bot |

Referencia exhaustiva, ejemplos de conversación completos y qué significa
cada mensaje automático que Nexo manda sin que se lo pidan:
**[docs/telegram.md](telegram.md)**.

## 4. Flujos típicos

**Aprobar un PR revisándolo vos:**
```text
Nexo: ✅ PR #18 listo. CI 6/6. https://github.com/.../pull/18
Tú:   /a 18
Nexo: PR #18 validado en 7ac91e2. Confirmá con /c 91ab… antes de 10 min.
Tú:   /c 91ab...
Nexo: 🟢 PR #18 fusionado. Continúo con issue #13.
```

**Agregar trabajo nuevo:** etiquetá el issue en GitHub con `agente:lista`
y mandá `/sig`, o encolalo directo con `/i N`.

**Pausar por la noche o antes de un cambio de infraestructura:**
`/pausa` — la tarea en curso termina de forma controlada, no se corta a
mitad de escritura. `/seguir` para retomar.

**Algo falló:** `/error` o `/error N` te da el resumen sin logs. Los logs
completos quedan en la VM (nunca por Telegram) — diagnóstico paso a paso en
[docs/runbook.md](runbook.md).

## 5. Cuando algo no anda

| Síntoma | Qué hacer |
|---|---|
| Nexo no responde | Esperar un minuto, reintentar `/estado`; si sigue mudo, entrar por Tailscale y ver `docs/runbook.md` |
| `/a N` dice «no aprobable» | Abrir el PR y mirar CI, conflictos y rama base |
| Código de confirmación vencido | Repetir `/a N` o `/todo`; no reusar el anterior |
| `/sig` no encuentra nada | Confirmar que hay un issue abierto con `agente:lista` y que no hay ya un PR de integración abierto |
| Un agente falla siempre por el mismo motivo | `/error N`, y si es un límite de proveedor (429), ver `docs/modelos.md` — no reintentar en bucle a mano |
| El bot responde a otra cuenta | Emergencia — parar servicios y corregir la allowlist ya. Ver `docs/runbook.md#parada-de-emergencia` |

Tabla completa de diagnóstico: [docs/telegram.md §10](telegram.md#10-solución-de-problemas-desde-telegram)
y [docs/runbook.md](runbook.md).

## 6. Para profundizar

| Si querés entender… | Andá a |
|---|---|
| Cada mensaje automático y ejemplos completos de conversación | [docs/telegram.md](telegram.md) |
| La máquina de estados, la cola y la recuperación ante reinicio | [docs/ciclo-autonomo.md](ciclo-autonomo.md) |
| Los diagramas de componentes y el flujo de ramas | [docs/arquitectura.md](arquitectura.md) |
| Qué modelo usa cada agente y por qué | [docs/agentes.md](agentes.md) y [docs/modelos.md](modelos.md) |
| El gateway OmniRoute: cuotas, fallback, límites de conexión | [docs/omniroute.md](omniroute.md) |
| Amenazas, secretos y por qué cada guardarraíl existe | [docs/seguridad.md](seguridad.md) |
| Por qué se decidió cada cosa (ESXi, OmniRoute, worktrees…) | [docs/decisiones.md](decisiones.md) |
| Qué repo está trabajando la flota hoy y por qué | [docs/proyecto-objetivo.md](proyecto-objetivo.md) |
| El avance tarea por tarea y las incidencias resueltas | [ESTADO.md](../ESTADO.md) |
