# Runbook — operación diaria

Qué comandos correr cuando algo pasa. Pensado para consultar desde el celular, por SSH vía Tailscale.

---

## Comandos frecuentes

```bash
cd ~/self-hosted-ai-devops
C=infra/docker-compose.yml

docker compose -f $C ps          # ¿está corriendo?
docker compose -f $C logs -f     # ver logs en vivo (Ctrl+C para salir)
docker compose -f $C restart     # reiniciar el orquestador
docker compose -f $C down        # 🛑 parada de emergencia
docker compose -f $C up -d       # levantar
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
codex --profile openai "responde: ok"  # el modelo responde
git -C ~/workspace/self-hosted-ai-devops status
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

Probalo aislado, nunca todos juntos:

```bash
codex --profile deepseek "responde: ok"
```

| Error | Causa |
|---|---|
| `401` / `invalid api key` | Clave mal copiada, o no exportada al entorno |
| `404` / `model not found` | El nombre del modelo cambió → [modelos.md](modelos.md#si-un-modelo-se-descontinúa) |
| `429` | Sin crédito o límite de tasa alcanzado. Revisá la consola |
| `connection refused` | `base_url` incorrecta, o región equivocada (caso Bailian) |

¿Las claves están en el entorno?

```bash
env | grep -E "OPENAI|DEEPSEEK|DASHSCOPE|ZHIPU" | sed 's/=.*/=***/'
```

Si no aparecen:

```bash
set -a && source ~/self-hosted-ai-devops/.env && set +a
```

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

Ante la duda, pedí ajustes en vez de aprobar. Aprobar es lo único que no tiene vuelta atrás fácil.
