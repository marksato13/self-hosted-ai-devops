# Seguridad

Este sistema es una máquina en tu casa que tiene un token de GitHub, cuatro claves de API y permiso para ejecutar comandos, controlada por un bot público de Telegram. Vale la pena dedicarle una página.

---

## Las tres cosas que sí o sí

### 🔴 1. El bot de Telegram es público

Es el riesgo más grande y el menos evidente.

Un bot de Telegram **no tiene dueño desde el punto de vista de quién puede escribirle**. Cualquiera que descubra `@mi_ai_devops_bot` —adivinándolo, o porque aparece en una búsqueda— puede mandarle mensajes. Si el bot ejecuta lo que le llega, esa persona tiene una shell en tu VM, con tus claves adentro.

**La defensa:** una allowlist de `chat_id`. El orquestador descarta todo mensaje cuyo remitente no esté en la lista.

```env
TELEGRAM_ALLOWED_CHAT_IDS=123456789
```

**Cómo se verifica de verdad:** escribirle desde **otra cuenta** y confirmar que no responde. Que funcione con tu cuenta no prueba nada sobre la allowlist.

Recomendado además:
- Nombre de usuario del bot poco adivinable (no `ai_bot`, no `devops_bot`).
- Registrar en los logs todo intento rechazado; si aparecen, alguien encontró el bot.
- Si sospechás que el token se filtró: `/revoke` en BotFather y generá uno nuevo.

---

### 🔴 2. Los secretos nunca entran al repositorio

El repo es **público**. Un token commiteado queda en el historial de git aunque después lo borres del archivo, y los bots que escanean GitHub buscando claves lo encuentran en minutos.

| Regla | Cómo se aplica |
|---|---|
| `.env` en `.gitignore` desde el primer commit | Ya está en este repo |
| `.env.example` con nombres, sin valores | Ya está |
| `~/.codex/config.toml` fuera del repo | Solo se versiona el `.example` |
| Permisos `600` en archivos con claves | `chmod 600 .env ~/.codex/config.toml` |
| El Revisor revisa el diff buscando secretos | En su prompt de sistema |

**Si una clave se filtra:** revocala en la consola del proveedor. Borrarla del archivo o reescribir el historial **no** sirve: hay que asumir que ya fue leída.

### El dato que hace esto urgente

Un informe de GitGuardian de marzo de 2026 midió que **los commits asistidos por IA filtran secretos a aproximadamente el doble de la tasa humana.** Claude Code, Cursor y Codex han commiteado credenciales en el último año.

Este proyecto tiene agentes autónomos commiteando sin supervisión, en un repo público, desde una máquina con cinco credenciales. La defensa automática no es opcional:

```bash
pipx install pre-commit && pre-commit install
```

Eso activa [`.pre-commit-config.yaml`](../.pre-commit-config.yaml): gitleaks corre **antes** de que el commit exista, y `no-commit-to-branch` bloquea cualquier commit directo a `main`.

Probá que funciona de verdad:

```bash
echo 'OPENAI_API_KEY=sk-proj-falsaparaprobar1234567890abcdef' > prueba.txt
git add prueba.txt && git commit -m "prueba"   # ← debe FALLAR
rm prueba.txt && git reset
```

Si el commit pasa, el hook no está instalado.

**Nunca uses `--no-verify` para saltear el hook.** Si es un falso positivo, agregá la excepción en `.gitleaks.toml`.

Tres capas, en orden de utilidad:

| Capa | Herramienta | Cuándo actúa |
|---|---|---|
| 1 | Gitleaks en pre-commit | Antes de que el commit se registre ← **la que importa** |
| 2 | Verificación en `scripts/integrar.sh` | Antes de abrir el PR |
| 3 | Push protection de GitHub | Del lado del servidor, último recurso |

---

### 🔴 3. `main` va protegida

Ningún agente puede escribir en la rama principal. Se entra solo por Pull Request, y el merge lo aprueba una persona.

GitHub → *Settings → Branches → Add rule* sobre `main`:

- [x] Require a pull request before merging
- [x] Do not allow bypassing the above settings

Es el freno de mano del sistema. Un agente autónomo con permiso de escritura en `main` funciona muy bien hasta el día en que no.

---

## Permisos: dar lo mínimo

### Token de GitHub

Usá un **fine-grained token**, nunca uno clásico con scope `repo` completo (ese da acceso a *todos* tus repositorios).

| Campo | Valor |
|---|---|
| Repository access | Only select repositories → `self-hosted-ai-devops` |
| Contents | Read and write |
| Pull requests | Read and write |
| Metadata | Read |
| Administration | ❌ Sin acceso |
| Todo lo demás | ❌ Sin acceso |

Ponele fecha de expiración (90 días) y anotate renovarlo.

### Sandbox de Codex

Codex CLI se ejecuta con permisos acotados al workspace. Evitá el modo full-auto sin restricciones sobre el sistema de archivos de la VM: un agente al que se le fue la mano dentro de `~/workspace` es un `git checkout` de distancia; uno con acceso libre al sistema, no.

En `~/.codex/config.toml`:

```toml
approval_policy = "on-failure"      # pide confirmación cuando algo falla
sandbox_mode    = "workspace-write" # escribe solo dentro del workspace
```

Confirmá los nombres exactos de estas opciones en la documentación de Codex CLI.

### Los agentes no ven los secretos

Ningún agente necesita leer `.env`. Las claves las consume Codex CLI desde variables de entorno; los agentes trabajan sobre el código, no sobre la configuración. Mantené `.env` fuera de cualquier ruta que los agentes tengan permitida.

---

## Red

Lo que está bien por diseño:

| Elemento | Estado | Por qué |
|---|---|---|
| Puertos abiertos en el router | **Ninguno** | Telegram usa polling: todo el tráfico es saliente |
| Acceso remoto | Tailscale | Red privada, sin exponer la IP de casa |
| SSH desde internet | No expuesto | Solo por Tailscale |
| Firewall de la VM | `ufw`, deniega entrante salvo SSH | El sistema no necesita recibir conexiones |

```bash
sudo ufw allow OpenSSH
sudo ufw --force enable
```

**No** redirijas el puerto 22 en el router. SSH expuesto a internet recibe escaneos automáticos desde el primer día.

---

## Gasto: el riesgo aburrido

Un agente con reintentos automáticos puede quemar créditos toda la noche sin que nadie lo note. No es una brecha de seguridad, pero se siente igual.

1. **Tope de gasto en la consola de cada proveedor.** Es la única capa que corta de verdad.
2. Alertas de consumo por correo.
3. `MAX_RETRIES_PER_TASK=2` en `.env` — el orquestador se autolimita, pero es software propio y puede fallar.

Detalle en [modelos.md](modelos.md#topes-de-gasto).

---

## Snapshots

Tomá un snapshot de la VM en el ESXi antes de cada cambio grande de configuración:

| Momento | Snapshot |
|---|---|
| VM creada, antes de instalar Ubuntu | #1 |
| Ubuntu + Docker + Tailscale listos | #2 |
| Stack completo funcionando | #3 |

Es lo más barato que existe para revertir una configuración que salió mal.

---

## Checklist antes de dejarlo corriendo solo

- [ ] Allowlist de Telegram verificada **desde otra cuenta**
- [ ] `.env` con permisos `600` y fuera del repo
- [ ] Ningún secreto en el historial de git
- [ ] Token de GitHub fine-grained, un solo repo, con expiración
- [ ] `main` protegida, con bypass deshabilitado
- [ ] `ufw` activo
- [ ] Sin puertos redirigidos en el router
- [ ] Topes de gasto puestos en las cuatro consolas
- [ ] `MAX_RETRIES_PER_TASK` configurado
- [ ] Snapshot #3 tomado
- [ ] Sandbox de Codex acotado al workspace

---

## Si algo salió mal

| Situación | Qué hacer, en este orden |
|---|---|
| El bot responde a desconocidos | `docker compose down` → arreglar allowlist → reverificar |
| Token de Telegram filtrado | `/revoke` en BotFather → nuevo token en `.env` → reiniciar |
| Clave de API filtrada | Revocarla en la consola del proveedor → generar otra |
| Token de GitHub filtrado | Revocarlo en GitHub → revisar commits y PRs recientes del repo |
| Un agente escribió algo raro en el repo | `main` está protegida: cerrá el PR sin mergear |
| La VM se comporta raro | Restaurar el snapshot #3 |
