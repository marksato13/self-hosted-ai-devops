# Estado de la implementación

Registro de avance del [plan de ejecución](docs/plan-ejecucion.md). Se actualiza al terminar cada tarea.

**Para el agente:** este archivo es tu punto de reanudación. Al empezar una sesión, leelo primero: la última tarea marcada indica dónde continuar. Al terminar una tarea verificada, marcá su casilla y anotá la fecha. Si una tarea falla dos veces, marcala 🔴 y anotá el error en «Incidencias».

**Estado general:** runner, cola y CI implementados en el repositorio. La
infraestructura de la VM continúa sin desplegar ni verificar.

---

## Progreso

| Fase | Tareas | Estado |
|---|---|---|
| **00 · El implementador** | **T00A–T00E** | ✅ Completa · *en esta VM* |
| 0 · Preparación | T001–T004 | ⬜ Sin empezar |
| 1 · VM en ESXi | T005–T006 | ⬜ Sin empezar |
| 2 · Ubuntu Server | T007–T009 | 🟡 En curso · falta firewall |
| 3 · Tailscale | T010–T011 | 🟡 En curso · falta prueba móvil |
| 4 · Docker | T012–T013 | 🟡 En curso · falta snapshot |
| 5 · LiteLLM | T014–T020 | ⬜ Sin empezar |
| 6 · Telegram | T021–T023 | ⬜ Sin empezar |
| 7 · OpenClaw | T024–T027 | ⬜ Sin empezar |
| 8 · Codex CLI | T028–T031 | ⬜ Sin empezar |
| 9 · GitHub | T032–T039 | ⬜ Sin empezar |
| 10 · La flota | T040–T045 | ⬜ Sin empezar |
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
- [ ] T002 👤 Cuatro claves de API obtenidas
- [ ] T003 👤 ⚠️ Topes de gasto en las cuatro consolas
- [ ] T004 👤 Cuenta de Tailscale + app en el celular

### Fase 1 — VM en ESXi
- [ ] T005 👤 VM `ai-devops` creada (4 vCPU · 6 GB · 30 GB · bridged)
- [ ] T006 👤 Snapshot `01-vm-vacia`

### Fase 2 — Ubuntu Server
- [x] T007 👤 Ubuntu Server 26.04 instalado, con OpenSSH — 2026-08-06
- [x] T008 🤖 Sistema actualizado y utilidades instaladas — 2026-08-06
- [ ] T009 🤖 Firewall `ufw` activo

### Fase 3 — Tailscale
- [x] T010 ⚙️ Tailscale instalado y autenticado — 2026-08-06
- [ ] T011 👤 SSH desde el celular **con el WiFi apagado**

### Fase 4 — Docker
- [x] T012 🤖 Docker funcionando sin `sudo` — 2026-08-06
- [ ] T013 👤 Snapshot `02-base-lista`

### Fase 5 — LiteLLM
- [ ] T014 🤖 Repositorio clonado en la VM
- [ ] T015 🤖 `.env` creado con permisos `600`
- [ ] T016 🤖 Claves internas generadas
- [ ] T017 ⚙️ Cuatro claves de proveedor cargadas
- [ ] T018 🤖 Gateway levantado y respondiendo
- [ ] T019 🤖 Los cinco modelos responden
- [ ] T020 🤖 Claves virtuales con presupuesto de 5 USD

### Fase 6 — Telegram
- [ ] T021 👤 Bot creado en BotFather
- [ ] T022 👤 `chat_id` obtenido
- [ ] T023 ⚙️ 🔴 Allowlist configurada

### Fase 7 — OpenClaw
- [ ] T024 👤 Imagen oficial confirmada en la documentación
- [ ] T025 🤖 Los tres contenedores arriba
- [ ] T026 👤 El bot responde a tu cuenta
- [ ] T027 👤 🔴 **El bot ignora a otra cuenta**

### Fase 8 — Codex CLI
- [ ] T028 🤖 Codex CLI instalado
- [ ] T029 🤖 `config.toml` con `wire_api = "responses"`
- [ ] T030 🤖 Variables de entorno persistidas
- [ ] T031 🤖 Los cinco perfiles responden

### Fase 9 — GitHub y guardarraíles
- [ ] T032 👤 Token fine-grained creado
- [ ] T033 ⚙️ `git` y `gh` configurados
- [ ] T034 👤 ⚠️ Rama `main` protegida
- [ ] T035 🤖 gitleaks y pre-commit instalados
- [ ] T036 🤖 🔴 **El hook bloquea un secreto de prueba**
- [ ] T037 🤖 Workspace preparado
- [ ] T038 👤 Primer PR abierto desde el celular
- [ ] T039 👤 Snapshot `03-stack-completo`

### Fase 10 — La flota
- [ ] T040 🤖 Worktrees creados a mano
- [ ] T041 🤖 Tres agentes en paralelo, un commit cada uno
- [ ] T042 🤖 `integrar.sh` abre un PR en borrador
- [ ] T043 ⚙️ PR aprobado y worktrees limpiados
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
| — | — | — | — |

---

## Decisiones tomadas durante la ejecución

Cuando el plan deja algo abierto y se resuelve sobre la marcha, anotarlo acá y llevarlo después a [docs/decisiones.md](docs/decisiones.md) como ADR.

| Fecha | Decisión | Motivo |
|---|---|---|
| 2026-08-06 | Cola local entre OpenClaw y el runner | Mantener GitHub, Codex, Docker y las claves fuera del contenedor de mensajería |
