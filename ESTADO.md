# Estado de la implementación

Registro de avance del [plan de ejecución](docs/plan-ejecucion.md). Se actualiza al terminar cada tarea.

**Para el agente:** este archivo es tu punto de reanudación. Al empezar una sesión, leelo primero: la última tarea marcada indica dónde continuar. Al terminar una tarea verificada, marcá su casilla y anotá la fecha. Si una tarea falla dos veces, marcala 🔴 y anotá el error en «Incidencias».

**Estado general:** OmniRoute desplegado, publicado solo en la tailnet, Codex
OAuth y OpenCode Free verificados. Kimi y DeepSeek están conectados como rutas
pagadas opcionales; sus pruebas se mantienen pendientes para evitar consumo.

---

## Progreso

| Fase | Tareas | Estado |
|---|---|---|
| **00 · El implementador** | **T00A–T00E** | ✅ Completa · *en esta VM* |
| 0 · Preparación | T001–T004 | ⬜ Sin empezar |
| 1 · VM en ESXi | T005–T006 | ⬜ Sin empezar |
| 2 · Ubuntu Server | T007–T009 | ✅ Completa |
| 3 · Tailscale | T010–T011 | 🟡 En curso · falta prueba móvil |
| 4 · Docker | T012–T013 | 🟡 En curso · falta snapshot |
| 5 · OmniRoute | T014–T020 | ✅ Completa |
| 6 · Telegram | T021–T023 | ✅ Completa |
| 7 · OpenClaw | T024–T027 | ✅ Completa |
| 8 · Codex CLI | T028–T031 | ✅ Completa |
| 9 · GitHub | T032–T039 | 🟡 En curso · NinjaSec incorporado; falta snapshot y prueba móvil del PR |
| 10 · La flota | T040–T045 | 🟡 En curso · agentes, PR y worktrees verificados (T040–T043); falta confirmar ciclo completo por Telegram (T044) y repasar checklist de seguridad (T045) |
| 11 · Bucle visual | T046–T058 | ⬜ Sin empezar · *opcional* |

Leyenda: ⬜ sin empezar · 🟡 en curso · ✅ completa · 🔴 bloqueada

---

## Tareas

### Fase 00 — El implementador *(en tu PC, no en la VM)*
- [x] T00A 👤 Comprobar si Codex y Node 22+ ya están instalados — 2026-08-06
- [x] T00B 👤 Codex CLI instalado (nativo de Windows, o npm en Linux/WSL) — 2026-08-06
- [x] T00C 👤 `codex login` con la cuenta de ChatGPT Plus — 2026-08-06
- [x] T00D 👤 Repositorio clonado en la PC — 2026-08-06
- [x] T00E 🤖 El implementador lee el plan y responde «T007» — 2026-08-06

### Fase 0 — Preparación
- [ ] T001 👤 ISO de Ubuntu Server 24.04 en el datastore
- [x] T002 👤 Suscripción ChatGPT Plus disponible — 2026-08-07
- [x] T003 👤 Política sin rutas de pago definida — 2026-08-07
- [ ] T004 👤 Cuenta de Tailscale + app en el celular

### Fase 1 — VM en ESXi
- [ ] T005 👤 VM `ai-devops` creada (4 vCPU · 6 GB · 30 GB · bridged)
- [ ] T006 👤 Snapshot `01-vm-vacia`

### Fase 2 — Ubuntu Server
- [x] T007 👤 Ubuntu Server 26.04 instalado, con OpenSSH — 2026-08-06
- [x] T008 🤖 Sistema actualizado y utilidades instaladas — 2026-08-06
- [x] T009 🤖 Firewall `ufw` activo — 2026-08-07

### Fase 3 — Tailscale
- [x] T010 ⚙️ Tailscale instalado y autenticado — 2026-08-06
- [ ] T011 👤 SSH desde el celular **con el WiFi apagado**

### Fase 4 — Docker
- [x] T012 🤖 Docker funcionando sin `sudo` — 2026-08-06
- [ ] T013 👤 Snapshot `02-base-lista`

### Fase 5 — OmniRoute
- [x] T014 🤖 Repositorio clonado en la VM — 2026-08-07
- [x] T015 🤖 `.env` creado con permisos `600` — 2026-08-07
- [x] T016 🤖 Claves internas generadas — 2026-08-07
- [x] T017 🤖 Claves comerciales eliminadas de `.env` — 2026-08-07
- [x] T018 🤖 Gateway levantado y respondiendo — 2026-08-07
- [x] T019 🤖 `auto/coding:free` responde con costo cero — 2026-08-07
- [x] T020 👤 Codex OAuth y OpenCode Free confirmados en dashboard — 2026-08-07

### Fase 6 — Telegram
- [x] T021 👤 Bot creado en BotFather — 2026-08-07
- [x] T022 👤 `chat_id` obtenido — 2026-08-07
- [x] T023 ⚙️ 🔴 Allowlist configurada — 2026-08-07

### Fase 7 — OpenClaw
- [x] T024 👤 Imagen oficial confirmada en la documentación — 2026-08-07
- [x] T025 🤖 OmniRoute y OpenClaw arriba y saludables — 2026-08-07
- [x] T026 👤 El bot responde a tu cuenta — 2026-08-07
- [x] T027 👤 🔴 **El bot ignora a otra cuenta** — 2026-08-07, confirmado por el operador

### Fase 8 — Codex CLI
- [x] T028 🤖 Codex CLI instalado — 2026-08-07
- [x] T029 🤖 `config.toml` con `wire_api = "responses"` — 2026-08-07
- [x] T030 🤖 Variables de entorno persistidas — 2026-08-07
- [x] T031 🤖 Los cinco perfiles responden — 2026-08-07

### Fase 9 — GitHub y guardarraíles
- [x] T032 👤 Credencial de GitHub disponible mediante `gh` — 2026-08-07
- [x] T033 ⚙️ `git` y `gh` configurados — 2026-08-07
- [x] T034 👤 ⚠️ Rama `main` protegida — 2026-08-07
- [x] T035 🤖 gitleaks y hook pre-commit instalados — 2026-08-07
- [x] T036 🤖 🔴 **Gitleaks bloquea un secreto sintético** — 2026-08-07
- [x] T037 🤖 Workspace y NinjaSec preparados — 2026-08-07
- [ ] T038 👤 Primer PR abierto desde el celular
- [ ] T039 👤 Snapshot `03-stack-completo`

### Fase 10 — La flota
- [x] T040 🤖 Worktrees creados a mano — 2026-08-07
- [x] T041 🤖 Tres agentes en paralelo, un commit cada uno — 2026-08-07
- [x] T042 🤖 `integrar.sh` abre un PR en borrador — 2026-08-07
- [x] T043 ⚙️ PR aprobado y worktrees limpiados — 2026-08-08: PR #3 (issue #2) aprobado y mergeado 2026-08-07; worktrees huérfanos limpiados 2026-08-08 (ver Incidencias)
- [ ] T044 🤖 Ciclo completo conectado a OpenClaw
- [ ] T045 👤 Checklist de seguridad repasado

### Fase 11 — Bucle visual *(solo si el proyecto tiene interfaz web)*
- [ ] T046 🤖 Variables del bucle en `.env` y carpetas creadas
- [ ] T047 🤖 Imagen `shotter` construida
- [ ] T048 🤖 Chromium renderiza sin escritorio
- [ ] T049 🤖 `config/capturas.json` con las rutas reales
- [ ] T050 🤖 Stage sirviendo en `:8080`
- [ ] T051 ⚙️ Stage abierto desde el celular por Tailscale
- [ ] T052 🤖 Primera tanda de capturas
- [ ] T053 🤖 Línea base fijada
- [ ] T054 🤖 **El comparador detecta un cambio deliberado**
- [ ] T055 ⚙️ Imagen recibida en Telegram
- [ ] T056 👤 Canal de WhatsApp decidido
- [ ] T057 🤖 Perfil `designer` y prueba de que **ve** la imagen
- [ ] T058 🤖 Vuelta completa del bucle

---

## Las tres que no se saltean

Si alguna de estas queda sin verificar, el sistema **no** está listo para correr sin supervisión:

| Tarea | Qué protege | Si se omite |
|---|---|---|
| **T003** | Topes de gasto en la consola | Un bucle nocturno quema el crédito |
| **T027** | Allowlist verificada desde otra cuenta | Un desconocido tiene shell en la VM |
| **T036** | El hook bloquea de verdad | Un agente commitea una clave en un repo público |
| **T054** *(si se hace la fase 11)* | El comparador ve un cambio deliberado | El bucle visual aprueba pantallas rotas en silencio |

---

## Incidencias

Anotar acá lo que falló dos veces y cómo se resolvió. Sirve para no repetir el diagnóstico.

| Fecha | Tarea | Qué pasó | Cómo se resolvió |
|---|---|---|---|
| 2026-08-08 | Issue #4 (ninjasec-platform) | El planner (perfiles `cx_gpt_5_5`, `cx_gpt_5_6_terra`, `cx_gpt_5_6_sol`) agotó el límite de reintentos con `429 Too Many Requests` en los tres perfiles de respaldo — la cuota de la cuenta ChatGPT/Codex quedó agotada hasta el 12/08/2026. El runner bloqueó el reencolado automático (comportamiento esperado) y quedó en `~/.local/state/ai-devops/queue/fallidas/issue-4.failed` tras el segundo intento (2026-08-07 22:56 y 2026-08-08 03:15). | Worktrees `issue-4-backend/docs/tests` limpiados con `scripts/limpiar-worktrees.sh 4` (sin commits, nada que perder). El issue #4 queda **sin reencolar** hasta que la cuota de Codex se reponga el 12/08/2026; reencolar manualmente después con `scripts/solicitar-issue.sh` o `encolar-siguiente.sh` cuando corresponda. |
| 2026-08-08 | T034 (`scripts/verificar.sh`) | El chequeo de «main protegida» usaba `$GITHUB_OWNER/$GITHUB_REPO`, pero en este `.env` esas variables apuntan al repo objetivo (`ninjasec-platform`, privado) para que el runner abra PRs ahí — no a la plataforma. La verificación de protección de rama sobre un repo privado sin plan Pro/Team devuelve 403, así que T034 reportaba FALLA aunque `self-hosted-ai-devops/main` sí está protegida (confirmado a mano: `enforce_admins=true`, check requerido `scripts-y-configuracion`). | **Resuelto:** `scripts/verificar.sh` ahora hardcodea `marksato13/self-hosted-ai-devops` en el chequeo de T034, independiente de las variables del repo objetivo. `./scripts/verificar.sh all` pasa de 51 OK/11 FALLAN a 53 OK/9 FALLAN (los 9 restantes son la Fase 11, bucle visual opcional, nunca iniciada). Nota aparte: `ninjasec-platform` al ser privado no puede verificar/fijar protección de rama por API sin plan GitHub Pro/Team — limitación de plan, no de código. |
| 2026-08-08 | Worktrees huérfanos adicionales | Además de issue-4, se encontraron worktrees ya mergeados sin limpiar: `issue-2-*` (PR #3 mergeado hace 1 día) en `ninjasec-platform`, y `infra-docs/runner/telegram/tests` (ramas `*-ciclo-*` ya mergeadas en `feat/robustez-plataforma`) en esta plataforma. Un directorio `issue-2-backend` había quedado corrupto (sin `.git`, con archivos `root:root` de un `.pytest_cache` escrito desde un contenedor). | Limpiados todos: `limpiar-worktrees.sh 2`, `git worktree remove` manual para los `infra-*`, y un contenedor Alpine descartable (`docker run --rm -v ... alpine rm -rf ...`) para los archivos `root:root` que `rm` normal no podía borrar por permisos. |

---

## Decisiones tomadas durante la ejecución

Cuando el plan deja algo abierto y se resuelve sobre la marcha, anotarlo acá y llevarlo después a [docs/decisiones.md](docs/decisiones.md) como ADR.

| Fecha | Decisión | Motivo |
|---|---|---|
| 2026-08-06 | Cola local entre OpenClaw y el runner | Mantener GitHub, Codex, Docker y las claves fuera del contenedor de mensajería |
| 2026-08-07 | Modo autónomo continuo habilitado | Allowlist confirmada; solo toma issues con `agente:lista`, uno por vez y sin auto-merge |
