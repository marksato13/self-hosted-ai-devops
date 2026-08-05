# Runbook — operación diaria

Qué comandos correr cuando algo pasa. Pensado para consultar desde el celular, por SSH vía Tailscale.

---

## Comandos frecuentes

```bash
cd ~/self-hosted-ai-devops
C=infra/docker-compose.yml

docker compose -f $C ps               # ¿están los 3 servicios?
docker compose -f $C logs -f          # logs en vivo (Ctrl+C para salir)
docker compose -f $C logs -f openclaw # solo el orquestador
docker compose -f $C logs -f litellm  # solo el gateway
docker compose -f $C restart          # reiniciar todo
docker compose -f $C down             # 🛑 parada de emergencia
docker compose -f $C up -d            # levantar
```

Gasto acumulado por agente:

```bash
curl -s http://localhost:4000/spend/logs \
  -H "Authorization: Bearer $LITELLM_MASTER_KEY" | jq
```

Worktrees en uso:

```bash
./scripts/limpiar-worktrees.sh --listar
```

Bucle visual (solo si está en uso):

```bash
V="-f infra/docker-compose.yml -f infra/docker-compose.visual.yml"
docker compose $V --profile visual ps          # ¿stage arriba?
curl -s localhost:${STAGE_PORT:-8080}/salud    # ¿responde?
tailscale serve status                         # ¿publicado en la tailnet?
sudo tailscale serve --https 8443 off          # bajarlo
du -sh ~/workspace/artefactos                  # cuánto ocupan las capturas
```

Vale la pena dejar alias en `~/.bashrc`:

```bash
alias ai-logs='docker compose -f ~/self-hosted-ai-devops/infra/docker-compose.yml logs -f'
alias ai-stop='docker compose -f ~/self-hosted-ai-devops/infra/docker-compose.yml down'
alias ai-up='docker compose -f ~/self-hosted-ai-devops/infra/docker-compose.yml up -d'
alias ai-ps='docker compose -f ~/self-hosted-ai-devops/infra/docker-compose.yml ps'
```

---

## Parada de emergencia

Si el sistema se descontrola —bucle de reintentos, commits raros, respuestas a desconocidos:

```bash
ai-stop
```

Corta todo de inmediato. `main` está protegida, así que nada de lo que hicieron los agentes llegó a la rama principal: revisá los PRs abiertos con calma y cerrá los que no correspondan.

---

## Chequeo de salud

```bash
docker compose -f $C ps                # contenedor arriba
tailscale status                       # red privada conectada
df -h /                                # espacio en disco
free -h                                # memoria
codex --profile planner "responde: ok"  # el modelo responde
git -C ~/workspace/self-hosted-ai-devops status
```

O de una sola vez, con el verificador del plan de ejecución:

```bash
./scripts/verificar.sh all      # sale 0 si todo pasa, 1 si algo falla
./scripts/verificar.sh 5        # solo una fase
```

---

## Diagnóstico

### El bot no responde en Telegram

```bash
docker compose -f $C ps      # ¿el contenedor está arriba?
docker compose -f $C logs --tail 50
```

| Lo que ves en los logs | Causa probable |
|---|---|
| `401 Unauthorized` | Token de Telegram mal copiado o revocado |
| `409 Conflict` | Hay otra instancia del bot corriendo con el mismo token |
| Sin movimiento al escribirle | Tu `chat_id` no está en la allowlist, o está mal escrito |
| El contenedor reinicia en bucle | Falta una variable en `.env`; mirá el error del arranque |

### El bot responde a desconocidos

🔴 Pará todo: `ai-stop`. Revisá `TELEGRAM_ALLOWED_CHAT_IDS` en `.env`, reiniciá y **volvé a probar desde otra cuenta**. Ver [seguridad.md](seguridad.md).

### Un perfil de Codex falla

Con el gateway en el medio, el problema puede estar en dos lugares. Aislalo de abajo hacia arriba.

**Primero: ¿responde el gateway?**

```bash
curl -s http://localhost:4000/health/liveliness
```

**Segundo: ¿responde ese modelo en el gateway?**

```bash
curl -s http://localhost:4000/v1/chat/completions \
  -H "Authorization: Bearer $LITELLM_MASTER_KEY" \
  -H "Content-Type: application/json" \
  -d '{"model":"backend","messages":[{"role":"user","content":"ok"}]}' | jq
```

Si falla acá, el problema es del proveedor: se arregla en `infra/litellm-config.yaml` y `docker compose restart litellm`.

| Error | Causa |
|---|---|
| `401` / `invalid api key` | Clave del proveedor mal copiada, o no llegó al contenedor |
| `404` / `model not found` | El nombre del modelo cambió → [modelos.md](modelos.md#si-un-modelo-se-descontinúa) |
| `429` | Sin crédito o límite de tasa. Revisá la consola del proveedor |
| `budget exceeded` | La clave virtual de ese agente agotó sus 5 USD. **Funcionando como debe** |
| `connection refused` | `api_base` incorrecta, o región equivocada (caso Bailian) |

**Tercero: si el gateway responde pero Codex no**, el problema está en `~/.codex/config.toml`:

```bash
codex --profile backend "responde: ok"
```

| Error | Causa |
|---|---|
| Error de `wire_api` | Debe ser `"responses"`. El valor `"chat"` ya no existe |
| `connection refused` a `localhost:4000` | El gateway está caído, o Codex corre dentro de un contenedor y no ve `localhost` |
| `401` contra el gateway | `LITELLM_MASTER_KEY` no está en el entorno |

```bash
env | grep -E "LITELLM|OPENAI|DEEPSEEK|DASHSCOPE|ZHIPU" | sed 's/=.*/=***/'
set -a && source ~/self-hosted-ai-devops/.env && set +a
```

### Los worktrees se desordenaron

```bash
./scripts/limpiar-worktrees.sh --listar
git worktree prune                    # borra referencias a directorios que ya no existen
./scripts/limpiar-worktrees.sh 12     # limpia un issue puntual
```

| Síntoma | Causa |
|---|---|
| `worktree add` dice que la rama ya existe | Hay una tarea vieja con ese número sin limpiar |
| `~/worktrees` ocupa mucho disco | Tareas terminadas sin limpiar. `df -h` y limpiá |
| Un worktree apunta a un directorio borrado | `git worktree prune` |

### Un commit fue bloqueado por gitleaks

**Funcionando como debe.** Revisá qué detectó:

```bash
gitleaks protect --staged --verbose
```

Si es un secreto real: sacalo del archivo y, si ya se había usado, **revocalo en la consola del proveedor**. Si es un falso positivo (un ejemplo en la documentación), agregá una excepción en `.gitleaks.toml` — nunca uses `--no-verify` para saltear el hook.

### `git push` rechazado

```bash
gh auth status
git -C ~/workspace/self-hosted-ai-devops remote -v
```

Suele ser el token: expirado, o sin permiso de escritura sobre el repo. Si el rechazo es sobre `main`, **está funcionando como debe** — hay que ir por un PR.

### La VM anda lenta

```bash
htop          # o: top
df -h /
docker stats --no-stream
```

Limpieza de Docker si el disco aprieta:

```bash
docker system prune -a       # ⚠️ borra imágenes no usadas
docker volume ls             # revisá antes de tocar volúmenes
```

### El bucle visual falla

Aislarlo por capas, igual que con los modelos: primero el stage, después el ojo,
después el modelo. Ver [bucle-visual.md](bucle-visual.md).

**Primero: ¿el stage sirve algo?**

```bash
curl -sI localhost:${STAGE_PORT:-8080}/ | head -1
ls "$STAGE_DIR"
```

| Síntoma | Causa |
|---|---|
| `404` en todas las rutas | `STAGE_DIR` vacío: el build no generó nada, o `STAGE_DIST_DIR` apunta mal |
| El contenedor no arranca | `STAGE_DIR` no existe en el host. Es un bind mount: tiene que existir antes |
| Se ve la versión vieja | Rarísimo — el `nginx.conf` manda `no-store`. Revisá que el build haya corrido |

**Segundo: ¿Chromium captura?**

```bash
docker compose $V run --rm shotter capturar.mjs --etiqueta diagnostico
jq '.fallos, .capturas | length' ~/workspace/artefactos/diagnostico/resumen.json
```

| Error | Causa |
|---|---|
| `Failed to launch browser` | Falta `--no-sandbox`. Va dentro de `capturar.mjs`, no en el compose |
| Cuelgue o `Target closed` | `/dev/shm` chico: falta el `shm_size: 1gb` del compose |
| `net::ERR_NAME_NOT_RESOLVED` | `shotter` no ve a `stage`: se levantó sin los **dos** archivos de compose |
| `Timeout … networkidle` | La página nunca queda quieta (polling, animación infinita). Usá `esperar: "load"` |

**Tercero: el comparador nunca ve diferencias.** Es el fallo peligroso, porque
parece que todo está bien. Reproducí T054: cambiá algo a propósito y exigí que
lo detecte. Si no lo ve, bajá `UMBRAL_VISUAL`.

**Cuarto: el Diseñador dice que no puede ver imágenes.**

```bash
codex --profile designer -i ~/workspace/artefactos/base/inicio__escritorio.png \
  "¿Qué texto se lee en esta imagen? Respondé solo el texto."
```

Si no devuelve el texto de la captura, el modelo del alias `designer` no es
multimodal. Se cambia en `infra/litellm-config.yaml` →
[modelos.md](modelos.md#el-diseñador-necesita-visión).

**El bucle revirtió los cambios.** Funcionando como debe: la accesibilidad
empeoró y volvió al punto de retorno. Las dos capturas llegaron al celular para
que decidas a mano.

### No entra el SSH desde el celular

```bash
tailscale status
sudo tailscale up            # si quedó desconectado
sudo systemctl status ssh
```

En el celular: la app de Tailscale tiene que estar activa y con la misma cuenta.

---

## Mantenimiento

### Semanal

```bash
sudo apt update && sudo apt -y upgrade
docker compose -f $C pull && docker compose -f $C up -d
```

Revisá también el consumo en las consolas de los cuatro proveedores.

### Mensual

- Snapshot de la VM en el ESXi.
- Revisar la fecha de expiración del token de GitHub.
- Borrar capturas viejas: `find ~/workspace/artefactos -maxdepth 1 -type d -mtime +30 -not -name base -exec rm -rf {} +`
- Repasar el checklist de [seguridad.md](seguridad.md#checklist-antes-de-dejarlo-corriendo-solo).
- Buscar intentos de acceso rechazados en los logs del bot.

---

## Recuperación

### Reiniciar el orquestador sin perder estado

```bash
docker compose -f $C restart
```

### Reconstruir desde cero

El estado vive en el volumen de Docker y en `.env`. El resto se reconstruye:

```bash
cd ~/self-hosted-ai-devops
git pull
docker compose -f infra/docker-compose.yml up -d --force-recreate
```

### Restaurar un snapshot

Panel del ESXi → VM `ai-devops` → *Acciones → Instantáneas → Restaurar*.

Perdés todo lo posterior al snapshot, incluido el `.env` si lo editaste después. Guardá una copia de las claves fuera de la VM (gestor de contraseñas), no solo dentro de ella.

---

## Qué mirar cuando llega un PR

Antes de aprobar desde el celular:

- [ ] ¿Los tests pasaron? (lo reporta el Revisor)
- [ ] ¿El diff toca solo los archivos que debía?
- [ ] ¿Hay alguna clave o ruta absoluta en el diff?
- [ ] ¿Agrega dependencias nuevas? Debería estar declarado en el commit
- [ ] ¿Cumple el criterio de aceptación del plan original?
- [ ] *(si es web)* ¿Las capturas del antes y el después muestran lo que decían?

Ante la duda, pedí ajustes en vez de aprobar. Aprobar es lo único que no tiene vuelta atrás fácil.
