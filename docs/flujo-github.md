# Flujo de GitHub y ejecución

El bot no tiene permiso para improvisar comandos: solo puede solicitar un
issue numérico.

## Preparación del repositorio destino

1. Crear el repositorio y una rama predeterminada `main`.
2. Activar protección de rama: PR obligatorio y sin bypass para agentes.
3. Crear un token fine-grained limitado al repositorio, con `Contents` y
   `Pull requests` en lectura/escritura y `Metadata` en lectura.
4. Clonar como `$HOME/workspace/<repositorio>` y comprobar `gh auth status`.
5. Añadir un `AGENTS.md` con los comandos reales de tests, lint y build.
6. Definir `AI_TARGET_REPO_DIR` con la ruta absoluta de ese clon.

El token vive en el almacén de `gh` del usuario del runner. Nunca se entrega al
contenedor de OpenClaw ni se guarda en el repositorio.

## Entrada desde Telegram

OpenClaw debe aplicar `dmPolicy: "allowlist"` y una lista de IDs numéricos. La
acción permitida para este flujo es:

```bash
solicitar-issue 12
```

El script rechaza texto, opciones, rutas, comodines y solicitudes duplicadas.
La petición queda en `AI_QUEUE_DIR` con permisos privados.

Cuando `AI_AUTONOMOUS_MODE=on`, el timer selecciona de forma determinista el
primer issue abierto con `agente:lista` y sin `bloqueada`. Solo lo hace si no
hay otra tarea ni un PR de integración abierto. El modo permanece apagado hasta
superar la prueba de allowlist T027.

Los comandos cerrados, la frontera de confianza y el diseño de aprobación en
dos fases se especifican en [ciclo-autonomo.md](ciclo-autonomo.md). No existe
una ruta de Telegram a una shell arbitraria.

## Procesamiento

`ai-devops-queue.path` despierta `ai-devops-queue.service` y
`ai-devops-queue.timer` reconcilia periódicamente. El servicio obtiene
un bloqueo exclusivo y ejecuta `scripts/ejecutar-issue.sh`:

1. Lee el issue mediante `gh issue view` y exige que esté abierto.
2. El Planificador produce JSON validado con `config/plan.schema.json`.
3. Solo se crean los worktrees que aparecen en el plan.
4. Backend, Tests y Docs corren mediante `codex exec`, con tiempo máximo. Son
   paralelos solo si `AI_AGENT_CONCURRENCY` es mayor que 1; el valor inicial es
   1 para respetar las cuotas de OmniRoute.
5. El integrador exige Gitleaks, ejecuta las pruebas detectadas, valida Compose
   y abre un único PR en borrador.

Los artefactos y logs quedan en `AI_STATE_DIR/issues/<numero>/`. Una solicitud
termina en `queue/completadas/` o `queue/fallidas/`; nunca desaparece sin dejar
estado.

Los estados se escriben atómicamente y cada transición queda también en
`events.jsonl`. El procesador acepta pausa/reanudación, ejecuta una sola tarea
por invocación y aplica `MAX_RETRIES_PER_TASK` con espera entre intentos. Al
reiniciarse, recupera solicitudes `.running` huérfanas.

## Ramas

| Rol | Rama |
|---|---|
| Backend | `feat/issue-<n>-backend` |
| Tests | `test/issue-<n>` |
| Docs | `docs/issue-<n>` |
| Integración | `integra/issue-<n>` |

Ningún agente trabaja en `main`. Si una rama de integración ya existe, el
runner se detiene en vez de borrarla. Un conflicto de merge se aborta y se
reporta, dejando el repositorio recuperable.

## Pull Request

El PR siempre comienza como borrador e informa por separado:

- ramas integradas;
- escaneo de secretos;
- tests ejecutados u omitidos;
- validación de Compose;
- revisión visual pendiente, cuando corresponde.

Solo una persona puede aprobar y fusionar el PR. La interfaz prevista exige
`aprobar PR N` y una segunda orden con código efímero ligado al chat, PR y SHA;
antes del merge se vuelven a comprobar la CI y el SHA. Después se ejecuta
`scripts/limpiar-worktrees.sh <n>`; las ramas sin fusionar se conservan.

## Recuperación

```bash
systemctl --user status ai-devops-queue.path ai-devops-queue.timer
journalctl --user -u ai-devops-queue.service
./scripts/control-runner.sh estado
find ~/.local/state/ai-devops/queue -maxdepth 2 -type f
find ~/.local/state/ai-devops/issues/12 -maxdepth 1 -type f
```

No se debe mover manualmente un archivo `.running` mientras el servicio esté
activo. Primero se detiene el servicio, se revisan los logs y luego se devuelve
la solicitud a `.pending` si el reintento es seguro.
