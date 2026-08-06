# Plan de ejecución

Instrucciones atómicas para implementar el proyecto. Escritas para que un agente (Codex CLI) las ejecute una por una, sin interpretar.

La versión narrativa, con explicaciones y contexto, está en [instalacion.md](instalacion.md). **Este documento no explica: ordena.**

---

## Contrato de ejecución

Reglas para el agente que ejecuta este plan. No son sugerencias.

1. **Una tarea a la vez, en orden.** No adelantar tareas ni agrupar.
2. **No pasar a la siguiente sin que la verificación dé OK.** Un fallo de infraestructura arrastrado tres tareas es imposible de diagnosticar.
3. **Si la verificación falla:** aplicar la acción de «Si falla». Si no se resuelve en **2 intentos**, PARAR y reportar. No improvisar una solución alternativa.
4. **No ejecutar tareas marcadas 👤 HUMANO.** Requieren un navegador, una app de celular o una decisión de una persona. Al llegar a una, PARAR, mostrar las instrucciones y esperar confirmación.
5. **Marcar el avance en [`../ESTADO.md`](../ESTADO.md)** después de cada tarea verificada.
6. **No inventar valores.** Si falta una clave, un token o una URL, PARAR y pedirla.
7. **Nunca escribir un secreto en un archivo versionado.** Solo en `.env`, que está en `.gitignore`.

### Leyenda

| Marca | Significa |
|---|---|
| 🤖 | Lo ejecuta el agente |
| 👤 | Lo hace una persona (navegador, celular, decisión) |
| ⚙️ | La persona obtiene un dato, el agente lo aplica |
| ♻️ | Idempotente: se puede repetir sin romper nada |
| ⚠️ | Destructivo o irreversible: confirmar antes |

### Formato de cada tarea

```
### T0NN · Título
Ejecuta · Depende de · Idempotente
Comandos → Verificación → Esperado → Si falla
```

### Verificación automática

Cada fase tiene su verificación agrupada:

```bash
./scripts/verificar.sh 5      # verifica la fase 5
./scripts/verificar.sh all    # todas las fases
```

---

# FASE 00 — El implementador

Instala el Codex CLI que va a **ejecutar este plan**. Sin él, las 58 tareas siguientes las hacés a mano.

> 📍 **Si ya tenés la VM andando**, seguí [docs/arranque.md](arranque.md) en vez de esta fase: instala el implementador **dentro de la VM**, que es lo más simple, e incluye el rodeo para hacer `codex login` en un servidor sin navegador. Esta fase describe la variante en tu PC.

**La variante de esta fase se hace en tu PC**, y sirve cuando la VM todavía no existe: así el implementador te acompaña también en las fases 0, 1 y 2, y sobrevive a revertir un snapshot.

### 🔴 Hay dos Codex en este proyecto. No son el mismo

Confundirlos es el error que más tiempo cuesta después, porque los síntomas aparecen recién en la Fase 8.

| | **Codex implementador** (esta fase) | **Codex de la flota** (T028) |
|---|---|---|
| Dónde vive | Tu PC (Windows nativo, WSL, Linux o macOS) | Dentro de la VM |
| Se autentica con | Tu suscripción **ChatGPT Plus** (`codex login`) | Una clave virtual de **LiteLLM** |
| Perfiles | Ninguno: usa el que viene por defecto | `planner`, `backend`, `tester`, `docs`, `reviewer`, `designer` |
| Para qué sirve | Montar este sistema | Escribir código en el repositorio objetivo |
| Si se pierde | Lo reinstalás y seguís donde ibas | Lo rehace T028 |

**No copies `config/codex-config.toml.example` en tu PC.** Ese archivo apunta a `http://localhost:4000`, que es LiteLLM **dentro de la VM** y no existirá hasta T018. En tu PC, el implementador usa la configuración por defecto y la suscripción.

### Por qué en la PC y no dentro de la VM

1. **La VM no existe hasta T005.** Alguien tiene que hacer las fases 0, 1 y 2.
2. **Los snapshots.** Snapshot #1 y #2 existen para poder volver atrás. Si el implementador vive dentro de la VM, revertir un snapshot lo borra a mitad del trabajo.
3. **Separación.** El implementador *configura* la flota; no es parte de ella.

A partir de la Fase 3, el implementador trabaja contra la VM por SSH (`ssh ai-devops "…"`), que queda disponible con Tailscale en T010–T011.

---

### T00A · Comprobar si ya está instalado
**Ejecuta:** 👤 · **Depende de:** — · ♻️

Antes de instalar nada, mirá si ya lo tenés. Codex CLI tiene instalador **nativo de Windows**: no siempre hace falta WSL.

```bash
codex --version
node --version
```

**Verificación:** si `codex` devuelve una versión y `node` es v22 o superior, **saltá a T00C**.

**Esperado:** en una PC donde ya se usó Codex, ambos responden. En una limpia, `command not found` — seguí por T00B.

---

### T00B · Instalar Codex CLI
**Ejecuta:** 👤 · **Depende de:** T00A · ♻️

Tres caminos según tu sistema. **Elegí uno solo.**

| Sistema | Cómo |
|---|---|
| **Windows** | Instalador nativo desde https://developers.openai.com/codex — queda en `%LOCALAPPDATA%\Programs\OpenAI\Codex` |
| **Linux / macOS** | `sudo npm i -g @openai/codex` (requiere Node 22+) |
| **Windows con WSL** | Igual que Linux, dentro de la distribución |

Si vas por npm y no tenés Node 22+:

```bash
curl -fsSL https://deb.nodesource.com/setup_22.x | sudo -E bash -
sudo apt-get install -y nodejs
```

**Verificación:**
```bash
codex --version && echo OK
```

**Esperado:** un número de versión y `OK`.

**Si falla:** con `EACCES` en npm, no lo arregles repitiendo `sudo npm`: configurá un prefijo propio con `npm config set prefix ~/.npm-global` y agregá `~/.npm-global/bin` al `PATH`. Si en Windows el comando no aparece tras instalar, cerrá y reabrí la terminal — el `PATH` no se recarga solo.

> ⚠️ **El nativo de Windows y el de WSL son instalaciones distintas**, con sesión y configuración separadas. Tener los dos y no saber cuál corriste es una fuente de confusión evitable: quedate con uno.

---

### T00C · Autenticar con la suscripción
**Ejecuta:** 👤 · **Depende de:** T00B · ♻️

```bash
codex login
```

Abre el navegador. Iniciar sesión con la **misma cuenta que tiene ChatGPT Plus**.

**Verificación:**
```bash
codex "responde solo con la palabra: ok"
```

**Esperado:** responde `ok`. Esa respuesta prueba las tres cosas a la vez: el binario corre, la sesión es válida y hay cuota disponible.

**Si falla:** confirmar los subcomandos con `codex --help` — cambian entre versiones. Si el navegador no abre solo (habitual en WSL), copiar la URL que imprime y pegarla a mano en Windows.

> 💡 Esto **no consume** tus claves de API. El implementador va por la suscripción que ya pagás; las cuatro claves de T002 son para la flota, no para él.

---

### T00D · Clonar el repositorio en la PC
**Ejecuta:** 👤 · **Depende de:** T00B · ♻️

```bash
git clone https://github.com/marksato13/self-hosted-ai-devops.git
cd self-hosted-ai-devops
```

**Verificación:**
```bash
test -f docs/plan-ejecucion.md && test -f scripts/verificar.sh && echo OK
```

**Esperado:** `OK`.

**Si falla:** revisar la URL del repositorio y que haya `git` instalado (`sudo apt-get install -y git`).

---

### T00E · Comprobar que el implementador entiende el plan
**Ejecuta:** 🤖 · **Depende de:** T00C, T00D · ♻️

Desde la raíz del repositorio:

```bash
codex "Leé docs/plan-ejecucion.md. Sin ejecutar nada, decime: \
cuál es la primera tarea que te toca a vos (🤖) y cuáles son \
todas las 👤 que tienen que estar hechas antes."
```

**Verificación:** la respuesta nombra **T007** como su primera tarea, y menciona T001–T006 como requisitos previos.

**Esperado:** eso exactamente. Si nombra T001 como suya, no leyó la leyenda ni el contrato de ejecución.

**Si falla:** confirmar que se ejecutó desde la raíz del repo y que el archivo existe. Si el modelo responde sin haber leído el archivo, hay que darle permiso de lectura del directorio — revisar el modo de aprobación con `codex --help`.

> ⚠️ **Antes de soltarlo a ejecutar.** Codex necesita permiso para correr comandos y editar archivos, y los modos de aprobación (`--full-auto` y similares) cambian entre versiones: confirmalos con `codex --help` antes de usarlos. Arrancá con aprobación manual hasta que veas cómo se comporta. El [contrato de ejecución](#contrato-de-ejecución) de arriba es lo que evita que se adelante.

---

# FASE 0 — Preparación

Sin esto no se puede empezar. Todo es 👤.

### T001 · Descargar la ISO de Ubuntu Server
**Ejecuta:** 👤 · **Depende de:** — · ♻️

Descargar **Ubuntu Server 24.04 LTS** de https://ubuntu.com/download/server y subirla al datastore del ESXi.

**Verificación:** la ISO aparece en el datastore del ESXi.

**Si falla:** verificar espacio libre en el datastore.

> ⚠️ **Server, no Desktop.** Si se descarga Desktop, la VM gasta 2–3 GB de RAM en un escritorio que nadie va a mirar. Ver [ADR-006](decisiones.md#adr-006--ubuntu-server-y-no-ubuntu-desktop).

---

### T002 · Obtener las cuatro claves de API
**Ejecuta:** 👤 · **Depende de:** — · ♻️

| Proveedor | Consola | Variable |
|---|---|---|
| OpenAI | https://platform.openai.com/api-keys | `OPENAI_API_KEY` |
| DeepSeek | https://platform.deepseek.com | `DEEPSEEK_API_KEY` |
| Alibaba Bailian | https://bailian.console.aliyun.com | `DASHSCOPE_API_KEY` |
| Zhipu / Z.ai | https://open.bigmodel.cn | `ZHIPU_API_KEY` |

Guardarlas en un gestor de contraseñas, **no** en un archivo de texto.

**Verificación:** las cuatro claves existen y están guardadas fuera de la VM.

**Si falla:** DeepSeek y Bailian requieren recargar saldo antes de emitir claves utilizables.

---

### T003 · ⚠️ Poner tope de gasto en cada consola
**Ejecuta:** 👤 · **Depende de:** T002 · ♻️

En las cuatro consolas: límite de gasto mensual y alerta por correo. Sugerido: **5 USD por proveedor**.

**Verificación:** las cuatro consolas muestran un límite configurado.

**Si falla:** si un proveedor no ofrece límite, usar prepago y no recargar de más.

> Esta es la **única** capa de tope que está fuera de tu propio código y por lo tanto no puede fallar por un bug. No la saltees.

---

### T004 · Crear cuenta de Tailscale
**Ejecuta:** 👤 · **Depende de:** — · ♻️

Cuenta gratuita en https://tailscale.com con login de Google o GitHub. Instalar la app en el celular y entrar con **la misma cuenta**.

**Verificación:** la app del celular muestra la red (todavía sin dispositivos).

---

# FASE 1 — VM en ESXi

### T005 · Crear la VM
**Ejecuta:** 👤 · **Depende de:** T001

Panel del ESXi → *Máquinas virtuales* → *Crear/Registrar VM* → *Crear una VM nueva*.

| Parámetro | Valor exacto |
|---|---|
| Nombre | `ai-devops` |
| Compatibilidad | ESXi 8.0 U2 o superior |
| SO invitado | Linux → Ubuntu Linux (64 bits) |
| vCPU | `4` |
| RAM | `6144` MB |
| Disco | `30` GB, aprovisionamiento fino |
| Controladora | VMware Paravirtual |
| Red | VM Network (**bridged**) |
| Adaptador | VMXNET3 |
| CD/DVD | Archivo ISO del datastore → ISO de Ubuntu Server |
| **Conectar al encender** | ✅ **marcado** |

**Verificación:** la VM aparece en el inventario, apagada.

**Si falla:** si no arranca del instalador en T007, casi siempre es «Conectar al encender» sin marcar.

---

### T006 · Snapshot #1
**Ejecuta:** 👤 · **Depende de:** T005

Con la VM **apagada**: *Acciones → Instantáneas → Tomar instantánea*. Nombre: `01-vm-vacia`.

**Verificación:** la instantánea aparece en el administrador.

---

# FASE 2 — Ubuntu Server

### T007 · Instalar Ubuntu Server
**Ejecuta:** 👤 · **Depende de:** T006

Encender la VM y abrir la consola web.

| Pantalla | Valor |
|---|---|
| Tipo de instalación | **Ubuntu Server** (no *minimized*) |
| Red | DHCP — **anotar la IP asignada** |
| Proxy / mirror | vacío / por defecto |
| Disco | disco entero, sin LVM cifrado |
| Nombre de host | `ai-devops` |
| **Instalar OpenSSH** | ✅ **marcado — obligatorio** |
| Snaps destacados | ninguno |

Al terminar: reiniciar y desconectar la ISO.

**Verificación:**
```bash
ssh USUARIO@IP_DE_LA_VM "lsb_release -ds"
```
**Esperado:** `Ubuntu 24.04...`

**Si falla:** sin OpenSSH marcado no hay SSH. Se instala desde la consola web con `sudo apt install openssh-server`.

> A partir de aquí, todas las tareas 🤖 se ejecutan **dentro de la VM por SSH**.

---

### T008 · Actualizar el sistema e instalar utilidades
**Ejecuta:** 🤖 · **Depende de:** T007 · ♻️

```bash
sudo apt update && sudo apt -y upgrade
sudo apt -y install git curl ca-certificates ufw jq openssl
```

**Verificación:**
```bash
command -v git curl jq openssl >/dev/null && echo OK
```
**Esperado:** `OK`

---

### T009 · Activar el firewall
**Ejecuta:** 🤖 · **Depende de:** T008 · ♻️

```bash
sudo ufw allow OpenSSH
sudo ufw --force enable
```

**Verificación:**
```bash
sudo ufw status | grep -q "Status: active" && echo OK
```
**Esperado:** `OK`

**Si falla:** no continuar sin firewall. Revisar `sudo ufw status verbose`.

> No rompe nada: todo el tráfico del sistema es **saliente** (polling de Telegram, APIs, GitHub).

---

# FASE 3 — Tailscale

### T010 · Instalar Tailscale
**Ejecuta:** ⚙️ · **Depende de:** T009 · ♻️

```bash
curl -fsSL https://tailscale.com/install.sh | sh
sudo tailscale up
```

Imprime una URL. 👤 **La persona debe abrirla y autenticar** con la cuenta de T004.

**Verificación:**
```bash
tailscale status >/dev/null 2>&1 && tailscale ip -4
```
**Esperado:** una IP `100.x.y.z`

**Si falla:** `sudo tailscale up --reset` y reautenticar.

---

### T011 · 👤 Probar el acceso desde el celular
**Ejecuta:** 👤 · **Depende de:** T010

En el celular: activar Tailscale, **apagar el WiFi** y conectar por SSH a la IP `100.x.y.z` con un cliente SSH (Termius, JuiceSSH).

**Verificación:** se abre la sesión SSH usando datos móviles.

**Si falla:** confirmar que ambos dispositivos están en la misma cuenta de Tailscale.

> Con el WiFi apagado. Es la única prueba que demuestra que no dependés de estar en casa.

---

# FASE 4 — Docker

### T012 · Instalar Docker
**Ejecuta:** 🤖 · **Depende de:** T011 · ♻️

```bash
curl -fsSL https://get.docker.com | sh
sudo usermod -aG docker $USER
```

Después: **cerrar la sesión SSH y volver a entrar.** El cambio de grupo no aplica hasta reconectar.

**Verificación:**
```bash
docker run --rm hello-world >/dev/null 2>&1 && docker compose version >/dev/null && echo OK
```
**Esperado:** `OK` sin usar `sudo`

**Si falla:** si pide `sudo`, no se reconectó la sesión.

---

### T013 · Snapshot #2
**Ejecuta:** 👤 · **Depende de:** T012

Apagar la VM (`sudo poweroff`) y tomar instantánea `02-base-lista`. Volver a encender.

**Verificación:** la instantánea existe.

---

# FASE 5 — LiteLLM (gateway)

> Sin esta fase, tres de los cinco agentes no funcionan. Codex solo habla la Responses API; DeepSeek, Qwen y GLM solo hablan Chat Completions. Ver [ADR-010](decisiones.md#adr-010--litellm-como-gateway-de-modelos).

### T014 · Clonar el repositorio
**Ejecuta:** 🤖 · **Depende de:** T012 · ♻️

```bash
cd ~ && git clone https://github.com/marksato13/self-hosted-ai-devops.git
cd ~/self-hosted-ai-devops && chmod +x scripts/*.sh
```

**Verificación:**
```bash
test -f ~/self-hosted-ai-devops/infra/litellm-config.yaml && echo OK
```

---

### T015 · Crear el archivo de secretos
**Ejecuta:** 🤖 · **Depende de:** T014

```bash
cd ~/self-hosted-ai-devops
cp .env.example .env
chmod 600 .env
```

**Verificación:**
```bash
stat -c '%a' ~/self-hosted-ai-devops/.env
```
**Esperado:** `600`

---

### T016 · Generar las claves internas
**Ejecuta:** 🤖 · **Depende de:** T015

```bash
cd ~/self-hosted-ai-devops
sed -i "s|^LITELLM_MASTER_KEY=.*|LITELLM_MASTER_KEY=sk-$(openssl rand -hex 24)|" .env
sed -i "s|^POSTGRES_PASSWORD=.*|POSTGRES_PASSWORD=$(openssl rand -hex 16)|"     .env
```

**Verificación:**
```bash
grep -qE '^LITELLM_MASTER_KEY=sk-.{48}$' .env && \
grep -qE '^POSTGRES_PASSWORD=.{32}$'     .env && echo OK
```

---

### T017 · Cargar las claves de proveedor
**Ejecuta:** ⚙️ · **Depende de:** T016

👤 La persona pega las cuatro claves de T002. El agente **no las inventa ni las pide por pantalla en claro**.

```bash
nano ~/self-hosted-ai-devops/.env
# OPENAI_API_KEY, DEEPSEEK_API_KEY, DASHSCOPE_API_KEY, ZHIPU_API_KEY
```

**Verificación:**
```bash
cd ~/self-hosted-ai-devops
for k in OPENAI_API_KEY DEEPSEEK_API_KEY DASHSCOPE_API_KEY ZHIPU_API_KEY; do
  grep -qE "^${k}=.+" .env || { echo "FALTA $k"; exit 1; }
done; echo OK
```

**Si falla:** PARAR y pedir la clave que falta. No continuar con claves vacías.

---

### T018 · Levantar el gateway
**Ejecuta:** 🤖 · **Depende de:** T017 · ♻️

```bash
cd ~/self-hosted-ai-devops
docker compose -f infra/docker-compose.yml up -d postgres litellm
sleep 30
```

**Verificación:**
```bash
curl -fsS http://localhost:4000/health/liveliness >/dev/null && echo OK
```

**Si falla:**
```bash
docker compose -f infra/docker-compose.yml logs litellm --tail 50
```
Causas frecuentes: `DATABASE_URL` mal formada, Postgres sin arrancar todavía.

---

### T019 · Probar los cinco modelos
**Ejecuta:** 🤖 · **Depende de:** T018 · ♻️

```bash
cd ~/self-hosted-ai-devops
set -a && source .env && set +a
for m in planner backend tester docs reviewer; do
  printf '%-9s ' "$m"
  curl -s http://localhost:4000/v1/chat/completions \
    -H "Authorization: Bearer $LITELLM_MASTER_KEY" \
    -H "Content-Type: application/json" \
    -d "{\"model\":\"$m\",\"messages\":[{\"role\":\"user\",\"content\":\"responde solo: ok\"}]}" \
    | jq -r '.choices[0].message.content // .error.message'
done
```

**Esperado:** los cinco responden `ok`.

**Si falla uno solo:** es problema **de ese proveedor**. Corregir `api_base` o el nombre del modelo en `infra/litellm-config.yaml`, luego `docker compose restart litellm`. Tabla de errores en [runbook.md](runbook.md#un-perfil-de-codex-falla).

**Si fallan todos:** el gateway no lee el `.env`. Revisar el bloque `environment` del compose.

---

### T020 · Crear claves virtuales con presupuesto
**Ejecuta:** 🤖 · **Depende de:** T019

```bash
cd ~/self-hosted-ai-devops
set -a && source .env && set +a
for a in planner backend tester docs reviewer; do
  curl -s -X POST http://localhost:4000/key/generate \
    -H "Authorization: Bearer $LITELLM_MASTER_KEY" \
    -H "Content-Type: application/json" \
    -d "{\"models\":[\"$a\"],\"max_budget\":5,\"budget_duration\":\"30d\",\"key_alias\":\"agente-$a\"}" \
    | jq -r '"\(.key_alias): \(.key)"'
done
```

**Verificación:** se imprimen cinco líneas `agente-X: sk-...`

**Si falla:** requiere que Postgres esté sano. `docker compose ps` debe mostrar `healthy`.

> Esto hace que un agente en bucle queme **sus** 5 USD y se detenga solo, sin arrastrar a los demás.

---

# FASE 6 — Bot de Telegram

### T021 · Crear el bot
**Ejecuta:** 👤 · **Depende de:** —

En Telegram, hablar con **@BotFather**:

```
/newbot
nombre visible:  AI DevOps
usuario:         <algo poco adivinable>_bot
```

Guardar el token `1234567890:AAF...`.

**Verificación:** BotFather devolvió un token.

> Un usuario poco adivinable es la primera capa de defensa. Evitar `ai_bot`, `devops_bot`.

---

### T022 · Obtener el chat_id
**Ejecuta:** 👤 · **Depende de:** T021

Escribirle a **@userinfobot** en Telegram. Responde con un ID numérico.

**Verificación:** se tiene un número de 9–10 dígitos.

---

### T023 · 🔴 Configurar la allowlist
**Ejecuta:** ⚙️ · **Depende de:** T022

```bash
nano ~/self-hosted-ai-devops/.env
# TELEGRAM_BOT_TOKEN=...
# TELEGRAM_ALLOWED_CHAT_IDS=<chat_id de T022>
```

**Verificación:**
```bash
cd ~/self-hosted-ai-devops
grep -qE '^TELEGRAM_BOT_TOKEN=.+:.+'        .env && \
grep -qE '^TELEGRAM_ALLOWED_CHAT_IDS=[0-9]' .env && echo OK
```

**Si falla:** PARAR. Sin allowlist no se levanta OpenClaw.

> Un bot de Telegram es **público**. Cualquiera que descubra su usuario puede escribirle. Si el bot ejecuta comandos y no hay allowlist, esa persona tiene shell en la VM, con las cinco credenciales adentro.

---

# FASE 7 — OpenClaw

### T024 · ⚙️ Confirmar la imagen oficial
**Ejecuta:** 👤 · **Depende de:** T023

Buscar en la documentación oficial de OpenClaw el nombre exacto de la imagen Docker y los nombres de sus variables de entorno. Cargar el valor:

```bash
nano ~/self-hosted-ai-devops/.env    # OPENCLAW_IMAGE=...
```

**Verificación:**
```bash
grep -qE '^OPENCLAW_IMAGE=.+' ~/self-hosted-ai-devops/.env && echo OK
```

**Si falla:** PARAR. No inventar un nombre de imagen.

> El compose de este repo es una **plantilla**. Si los nombres de variable de OpenClaw difieren de los de `infra/docker-compose.yml`, ajustarlos aquí antes de levantar.

---

### T025 · Levantar el stack completo
**Ejecuta:** 🤖 · **Depende de:** T024 · ♻️

```bash
cd ~/self-hosted-ai-devops
docker compose -f infra/docker-compose.yml up -d
sleep 20
docker compose -f infra/docker-compose.yml ps
```

**Verificación:** los tres servicios (`postgres`, `litellm`, `openclaw`) en estado `Up`.

**Si falla:** `docker compose logs openclaw --tail 50`. Si reinicia en bucle, falta una variable en `.env`.

---

### T026 · Prueba 1 de la allowlist — tu cuenta
**Ejecuta:** 👤 · **Depende de:** T025

Escribirle `hola` al bot desde **tu** cuenta de Telegram.

**Verificación:** el bot responde.

**Si falla:** `docker compose logs -f openclaw`. Un `401` es token mal copiado; un `409`, otra instancia con el mismo token.

---

### T027 · 🔴 Prueba 2 de la allowlist — otra cuenta
**Ejecuta:** 👤 · **Depende de:** T026

Escribirle al bot desde **otra** cuenta de Telegram (pedirle a alguien, o usar una segunda cuenta).

**Verificación:** el bot **ignora** el mensaje, y queda registro del rechazo en los logs.

**Si el bot responde:** 🛑 **PARAR TODO.**
```bash
docker compose -f infra/docker-compose.yml down
```
Corregir `TELEGRAM_ALLOWED_CHAT_IDS` y repetir T025–T027.

> Que funcione con tu cuenta no prueba **nada** sobre la allowlist. Esta es la prueba que importa. No se saltea.

---

# FASE 8 — Codex CLI

### T028 · Instalar Codex CLI
**Ejecuta:** 🤖 · **Depende de:** T027 · ♻️

```bash
sudo apt -y install nodejs npm
sudo npm i -g @openai/codex
```

**Verificación:**
```bash
codex --version && echo OK
```

---

### T029 · Instalar la configuración de perfiles
**Ejecuta:** 🤖 · **Depende de:** T028 · ♻️

```bash
mkdir -p ~/.codex
cp ~/self-hosted-ai-devops/config/codex-config.toml.example ~/.codex/config.toml
chmod 600 ~/.codex/config.toml
```

**Verificación:**
```bash
grep -q 'wire_api = "responses"'          ~/.codex/config.toml && \
grep -q 'base_url = "http://localhost:4000/v1"' ~/.codex/config.toml && echo OK
```

**Si falla:** `wire_api` **debe** ser `"responses"`. El valor `"chat"` fue eliminado de Codex en febrero de 2026.

---

### T030 · Persistir las variables de entorno
**Ejecuta:** 🤖 · **Depende de:** T029 · ♻️

```bash
LINE='set -a && source ~/self-hosted-ai-devops/.env && set +a'
grep -qxF "$LINE" ~/.bashrc || echo "$LINE" >> ~/.bashrc
source ~/.bashrc
```

**Verificación:**
```bash
test -n "$LITELLM_MASTER_KEY" && echo OK
```

---

### T031 · Probar los cinco perfiles
**Ejecuta:** 🤖 · **Depende de:** T030 · ♻️

```bash
for p in planner backend tester docs reviewer; do
  printf '%-9s ' "$p"
  codex --profile "$p" "responde solo: ok" 2>&1 | tail -1
done
```

**Esperado:** los cinco responden.

**Si falla uno:** aislar por capas — primero el gateway (T019), después Codex. Ver [runbook.md](runbook.md#un-perfil-de-codex-falla).

---

# FASE 9 — GitHub y guardarraíles

### T032 · Crear el token de GitHub
**Ejecuta:** 👤 · **Depende de:** —

GitHub → *Settings → Developer settings → Personal access tokens → **Fine-grained***:

| Campo | Valor |
|---|---|
| Repository access | Only select repositories → `self-hosted-ai-devops` |
| Contents | Read and write |
| Pull requests | Read and write |
| Metadata | Read |
| Administration | Sin acceso |
| Expiración | 90 días |

**Verificación:** se obtuvo un token `github_pat_...`.

> Nada de tokens clásicos con scope `repo` completo: dan acceso a **todos** tus repositorios.

---

### T033 · Configurar git y gh
**Ejecuta:** ⚙️ · **Depende de:** T032

```bash
nano ~/self-hosted-ai-devops/.env       # GITHUB_TOKEN=...
set -a && source ~/self-hosted-ai-devops/.env && set +a

git config --global user.name  "AI DevOps Bot"
git config --global user.email "bot@localhost"
sudo apt -y install gh
gh auth login --with-token <<< "$GITHUB_TOKEN"
```

**Verificación:**
```bash
gh auth status >/dev/null 2>&1 && echo OK
```

---

### T034 · ⚠️ Proteger la rama main
**Ejecuta:** 👤 · **Depende de:** T032

GitHub → *Settings → Branches → Add rule* sobre `main`:

- [x] Require a pull request before merging
- [x] Do not allow bypassing the above settings

**Verificación:**
```bash
gh api repos/marksato13/self-hosted-ai-devops/branches/main/protection >/dev/null 2>&1 && echo OK
```

**Si falla:** sin esto, un agente puede escribir en `main`. Es el freno de mano del sistema ([ADR-009](decisiones.md#adr-009--el-merge-lo-aprueba-una-persona)).

---

### T035 · Instalar gitleaks y pre-commit
**Ejecuta:** 🤖 · **Depende de:** T033 · ♻️

```bash
sudo apt -y install pipx
pipx install pre-commit && pipx ensurepath && source ~/.bashrc

GL=8.28.0
curl -sSL "https://github.com/gitleaks/gitleaks/releases/download/v${GL}/gitleaks_${GL}_linux_x64.tar.gz" \
  | sudo tar -xz -C /usr/local/bin gitleaks

cd ~/self-hosted-ai-devops && pre-commit install
```

**Verificación:**
```bash
gitleaks version >/dev/null && test -f ~/self-hosted-ai-devops/.git/hooks/pre-commit && echo OK
```

---

### T036 · 🔴 Comprobar que el hook realmente bloquea
**Ejecuta:** 🤖 · **Depende de:** T035

```bash
cd ~/self-hosted-ai-devops
echo 'OPENAI_API_KEY=sk-proj-falsaparaprobar1234567890abcdef' > /tmp/prueba-secreto.txt
cp /tmp/prueba-secreto.txt ./prueba-secreto.txt
git add prueba-secreto.txt
git commit -m "prueba que debe fallar" ; RC=$?
git reset -q && rm -f prueba-secreto.txt /tmp/prueba-secreto.txt
test $RC -ne 0 && echo "OK: el hook bloqueó el commit" || echo "FALLO: el commit pasó"
```

**Esperado:** `OK: el hook bloqueó el commit`

**Si el commit pasa:** el hook no está activo. Repetir T035. **No continuar** — es la defensa contra que un agente filtre una clave, y los commits con IA filtran secretos a ~2× la tasa humana.

---

### T037 · Preparar el workspace
**Ejecuta:** 🤖 · **Depende de:** T033 · ♻️

```bash
mkdir -p ~/workspace && cd ~/workspace
test -d self-hosted-ai-devops || git clone https://github.com/marksato13/self-hosted-ai-devops.git
chmod +x ~/workspace/self-hosted-ai-devops/scripts/*.sh
```

**Verificación:**
```bash
test -x ~/workspace/self-hosted-ai-devops/scripts/nueva-tarea.sh && echo OK
```

---

### T038 · Prueba de fuego: un PR desde el celular
**Ejecuta:** 👤 · **Depende de:** T037

Desde Telegram:
```
corrige el typo de la línea 3 del README y abre un PR
```

**Verificación:** llega al celular el link de un PR abierto en GitHub.

**Si falla:** revisar `docker compose logs -f openclaw`. Un `git push` rechazado suele ser el token sin permiso de escritura.

---

### T039 · Snapshot #3
**Ejecuta:** 👤 · **Depende de:** T038

Instantánea `03-stack-completo`. Es el último estado bueno conocido.

---

# FASE 10 — La flota completa

### T040 · Crear los worktrees a mano
**Ejecuta:** 🤖 · **Depende de:** T038 · ♻️

```bash
cd ~/workspace/self-hosted-ai-devops
./scripts/nueva-tarea.sh 1
git worktree list
```

**Verificación:** `git worktree list` muestra 4 entradas (el principal + tres de `issue-1`).

**Si falla:** si dice que una rama ya existe, limpiar con `./scripts/limpiar-worktrees.sh 1`.

> Correr el flujo a mano una vez antes de automatizarlo. Un script que funciona por razones que no conocés es un script que no podés arreglar.

---

### T041 · Los tres agentes en paralelo
**Ejecuta:** 🤖 · **Depende de:** T040

```bash
WT=~/workspace/worktrees
(cd $WT/issue-1-backend && codex --profile backend "agrega un comentario de una línea al final de README.md") &
(cd $WT/issue-1-tests   && codex --profile tester  "crea tests/prueba.md con el texto: prueba") &
(cd $WT/issue-1-docs    && codex --profile docs    "agrega una línea al final de docs/runbook.md") &
wait
```

**Verificación:**
```bash
cd ~/workspace/self-hosted-ai-devops
for b in feat/issue-1-backend test/issue-1 docs/issue-1; do
  git log --oneline -1 "$b" || echo "SIN COMMIT: $b"
done
```
**Esperado:** un commit en cada una de las tres ramas.

**Si falla:** los prompts de sistema completos están en [agentes.md](agentes.md).

---

### T042 · Integrar y abrir un PR
**Ejecuta:** 🤖 · **Depende de:** T041

```bash
cd ~/workspace/self-hosted-ai-devops
./scripts/integrar.sh 1
```

**Verificación:** imprime la URL de un PR **en borrador**.

**Si falla, según el código de salida:**

| Código | Significa | Acción |
|---|---|---|
| 2 | Conflicto de merge | Resolver, o escalar si es ambiguo |
| 3 | 🔴 Secreto detectado | **No** abrir el PR. Revisar el diff |
| 4 | Tests fallaron | Devolver al agente correspondiente (máx. 2 reintentos) |
| 5 | `docker-compose` inválido | Corregir el YAML |

---

### T043 · Aprobar y limpiar
**Ejecuta:** ⚙️ · **Depende de:** T042

👤 Revisar el PR desde el celular con el checklist de [runbook.md](runbook.md#qué-mirar-cuando-llega-un-pr) y mergear si está bien.

```bash
cd ~/workspace/self-hosted-ai-devops
./scripts/limpiar-worktrees.sh 1
```

**Verificación:**
```bash
git worktree list | wc -l
```
**Esperado:** `1` (solo el principal)

---

### T044 · Conectar el ciclo a OpenClaw
**Ejecuta:** 🤖 · **Depende de:** T043

Configurar OpenClaw para que al recibir un mensaje ejecute esta secuencia:

| # | Paso | Comando |
|---|---|---|
| 1 | Planificar | `codex --profile planner "<tarea>"` → plan en JSON |
| 2 | Preparar | `./scripts/nueva-tarea.sh <issue>` |
| 3 | Ejecutar | los tres perfiles en paralelo, uno por worktree |
| 4 | Integrar | `./scripts/integrar.sh <issue>` |
| 5 | Notificar | mandar la URL del PR por Telegram |
| 6 | Limpiar | `./scripts/limpiar-worktrees.sh <issue>` al aprobar |

Aplicar los tres frenos: `MAX_RETRIES_PER_TASK`, `TASK_TIMEOUT_MINUTES` y el presupuesto por clave virtual.

**Verificación:** una tarea mandada por Telegram genera tres ramas y **un solo** PR consolidado, sin tocar la PC.

**Si falla:** decidir aquí si OpenClaw invoca los comandos directamente o hace falta un wrapper — es la [decisión abierta](decisiones.md#decisiones-todavía-abiertas) que corresponde resolver en este punto, con el sistema ya andando a mano.

---

### T045 · Cierre
**Ejecuta:** 👤 · **Depende de:** T044

Repasar el [checklist de seguridad](seguridad.md#checklist-antes-de-dejarlo-corriendo-solo) completo antes de dejar la flota corriendo sin supervisión.

**Verificación:** los once puntos del checklist marcados.

---

# FASE 11 — Bucle visual

Hasta acá la flota escribe código a ciegas. Esta fase le da ojos: capturas de
pantalla desde una VM sin escritorio, un stage mirable desde el celular y un
informe con imágenes. Contexto completo en [bucle-visual.md](bucle-visual.md).

**Saltear esta fase es válido** si el proyecto no tiene interfaz web. Todo lo
anterior funciona sin ella.

---

### T046 · Completar las variables del bucle visual
**Ejecuta:** 🤖 · **Depende de:** T044 · ♻️

Agregar al `.env` de la VM (los nombres ya están en `.env.example`):

```bash
cd ~/self-hosted-ai-devops
cat >> .env <<'EOF'
STAGE_DIR=/home/USUARIO/workspace/stage
ARTEFACTOS_DIR=/home/USUARIO/workspace/artefactos
STAGE_PORT=8080
STAGE_BUILD_CMD=
STAGE_DIST_DIR=dist
UMBRAL_VISUAL=0.1
WHATSAPP_MODO=off
EOF
sed -i "s|/home/USUARIO|$HOME|g" .env
mkdir -p "$HOME/workspace/stage" "$HOME/workspace/artefactos"
```

**Verificación:**
```bash
set -a && source .env && set +a
test -d "$STAGE_DIR" && test -d "$ARTEFACTOS_DIR" && echo OK
```

> `STAGE_BUILD_CMD` queda vacío a propósito: depende del proyecto que se vaya a
> desarrollar. Un sitio estático no necesita nada; una app React lleva
> `npm ci && npm run build`.

---

### T047 · Construir la imagen del shotter
**Ejecuta:** 🤖 · **Depende de:** T046 · ♻️

```bash
cd ~/self-hosted-ai-devops
docker compose -f infra/docker-compose.yml \
               -f infra/docker-compose.visual.yml \
               --profile visual build shotter
```

**Verificación:**
```bash
docker run --rm --entrypoint npx shotter:local playwright --version
```
**Esperado:** imprime la versión de Playwright.

**Si falla:** la descarga son ~2 GB; con poco espacio en disco muere a la mitad.
`df -h /` debe mostrar al menos 8 GB libres. Si el error es de versión, la de
`infra/shotter/package.json` tiene que coincidir con el `ARG PW_VERSION` del
Dockerfile.

---

### T048 · Comprobar que Chromium renderiza sin escritorio
**Ejecuta:** 🤖 · **Depende de:** T047

Esta es la prueba de que Ubuntu **Server** alcanza: no hay X11 en esta máquina.

```bash
docker run --rm -v "$ARTEFACTOS_DIR:/salida" --entrypoint node shotter:local -e "
  const { chromium } = require('/app/node_modules/playwright');
  (async () => {
    const b = await chromium.launch({ args: ['--no-sandbox'] });
    const p = await b.newPage();
    await p.setContent('<h1 style=font-size:80px>hola</h1>');
    await p.screenshot({ path: '/salida/prueba-headless.png' });
    await b.close();
  })();"
```

**Verificación:**
```bash
test -s "$ARTEFACTOS_DIR/prueba-headless.png" && echo OK
```

**Si falla:** `--no-sandbox` es obligatorio dentro de Docker. Si el error menciona
`/dev/shm`, falta el `shm_size` del compose.

---

### T049 · Configurar qué se captura
**Ejecuta:** 🤖 · **Depende de:** T046 · ♻️

```bash
cd ~/self-hosted-ai-devops
cp config/capturas.json.example config/capturas.json
```

Editar `rutas` para que coincidan con las páginas reales del proyecto. Empezar
con **una sola ruta**: se agregan después.

**Verificación:**
```bash
jq -e '.rutas | length >= 1' config/capturas.json >/dev/null && echo OK
```

> Cada ruta se captura una vez por viewport. Tres rutas son nueve imágenes por
> vuelta, y las imágenes las paga el Diseñador en tokens.

---

### T050 · Levantar el stage
**Ejecuta:** 🤖 · **Depende de:** T049 · ♻️

Con una página de prueba, antes de conectarlo a un worktree real:

```bash
set -a && source ~/self-hosted-ai-devops/.env && set +a
echo '<h1>stage vivo</h1>' > "$STAGE_DIR/index.html"
cd ~/self-hosted-ai-devops
docker compose -f infra/docker-compose.yml \
               -f infra/docker-compose.visual.yml \
               --profile visual up -d stage
```

**Verificación:**
```bash
curl -fsS "http://localhost:${STAGE_PORT}/salud" && echo OK
```

**Si falla:** `docker compose logs stage --tail 20`. El error más común es
`STAGE_DIR` inexistente o mal escrito en `.env`.

---

### T051 · Publicar el stage en la tailnet
**Ejecuta:** ⚙️ · **Depende de:** T050 · ♻️

🤖 En la VM:
```bash
sudo tailscale serve --bg --https 8443 "http://127.0.0.1:${STAGE_PORT}"
tailscale status --json | jq -r '.Self.DNSName'
```

👤 Abrir `https://<ese-host>:8443` **desde el celular**, con Tailscale encendido.

**Verificación:** el celular muestra «stage vivo».

**Si falla:** verificar que el celular tenga Tailscale activo (es la misma
condición que el SSH de T011). Si dice que HTTPS no está habilitado, activar
MagicDNS y certificados en la consola de Tailscale.

> **`serve`, no `funnel`.** `funnel` publicaría el stage a internet entero. Acá
> se muestra trabajo a medio hacer escrito por un agente.
> Ver [ADR-017](decisiones.md#adr-017--el-stage-va-a-la-tailnet-no-a-internet).

---

### T052 · Primera captura
**Ejecuta:** 🤖 · **Depende de:** T050 · ♻️

```bash
cd ~/workspace/self-hosted-ai-devops
./scripts/capturar.sh prueba
```

**Verificación:**
```bash
ls "$ARTEFACTOS_DIR/prueba"/*.png | wc -l
```
**Esperado:** una imagen por combinación de ruta y viewport (3 rutas × 3
viewports = 9), más `accesibilidad.json` y `resumen.json`.

**Si falla:** `jq '.fallos' "$ARTEFACTOS_DIR/prueba/resumen.json"` dice cuántas
rutas no cargaron. Una ruta que da 404 en el stage de prueba es esperable:
dejar solo `/` en `config/capturas.json` hasta tener el proyecto real.

---

### T053 · Fijar la línea base
**Ejecuta:** 🤖 · **Depende de:** T052 · ♻️

La referencia contra la que se compara todo después es el estado de `main`.

```bash
cp -r "$ARTEFACTOS_DIR/prueba" "$ARTEFACTOS_DIR/base"
```

**Verificación:**
```bash
test -d "$ARTEFACTOS_DIR/base" && echo OK
```

---

### T054 · Comprobar que el comparador detecta un cambio
**Ejecuta:** 🤖 · **Depende de:** T053

Un comparador que nunca falla no está comparando nada. Se le mete un cambio a
propósito y **tiene que** verlo.

```bash
cd ~/workspace/self-hosted-ai-devops
set -a && source ~/self-hosted-ai-devops/.env && set +a

echo '<h1 style="color:red">stage vivo</h1>' > "$STAGE_DIR/index.html"
./scripts/capturar.sh cambiado
./scripts/comparar.sh base cambiado ; RC=$?

echo '<h1>stage vivo</h1>' > "$STAGE_DIR/index.html"     # dejar como estaba
test $RC -eq 1 && echo "OK: detectó la diferencia" || echo "FALLO: no vio el cambio"
```

**Esperado:** `OK: detectó la diferencia` y un PNG con el título pintado en rojo
en `$ARTEFACTOS_DIR/cambiado/diff/`.

**Si dice FALLO:** el umbral está demasiado alto, o las dos capturas salieron
del mismo HTML porque nginx cacheó. El `nginx.conf` de este repo manda
`no-store` justamente por esto.

---

### T055 · Reportar una imagen por Telegram
**Ejecuta:** ⚙️ · **Depende de:** T054 · ♻️

```bash
cd ~/workspace/self-hosted-ai-devops
./scripts/reportar.sh "prueba del bucle visual" "$ARTEFACTOS_DIR/base/"*escritorio.png
```

**Verificación:** 👤 la imagen llega al celular, en el chat del bot.

**Si falla:** un `400 chat not found` es un `chat_id` mal copiado; un
`403 bot was blocked` significa que bloqueaste tu propio bot.

---

### T056 · Decidir el canal de WhatsApp
**Ejecuta:** 👤 · **Depende de:** T055

| Opción | Cuándo elegirla |
|---|---|
| `WHATSAPP_MODO=off` | **Recomendado.** Telegram ya manda las imágenes |
| `WHATSAPP_MODO=cloud` | Hay cuenta de Meta Business y se acepta la ventana de 24 h |
| `WHATSAPP_MODO=openclaw` | Se usa el canal de OpenClaw, con un **número secundario** |

**Verificación:** `WHATSAPP_MODO` tiene un valor de esos tres en `.env`.

> Con la API oficial, fuera de las 24 h desde tu último mensaje **el informe no
> llega**: hace falta una plantilla aprobada, y una plantilla no lleva una
> captura arbitraria. Con un puente no oficial sobre tu número personal, el
> riesgo es el baneo de la cuenta.
> Ver [ADR-016](decisiones.md#adr-016--las-imágenes-por-telegram-whatsapp-como-aviso).

---

### T057 · Dar de alta el perfil `designer`
**Ejecuta:** 🤖 · **Depende de:** T031 · ♻️

El modelo del Diseñador tiene que aceptar **imágenes de entrada**. Uno de texto
no sirve acá, por barato que sea.

```bash
# 1. El alias ya está en infra/litellm-config.yaml; recargar el gateway
cd ~/self-hosted-ai-devops
docker compose -f infra/docker-compose.yml up -d --force-recreate litellm

# 2. Clave virtual con su propio presupuesto
curl -sS -X POST http://localhost:4000/key/generate \
  -H "Authorization: Bearer $LITELLM_MASTER_KEY" \
  -H "Content-Type: application/json" \
  -d '{"models":["designer"],"max_budget":5,"budget_duration":"30d","key_alias":"agente-designer"}'
```

**Verificación:** el perfil ve de verdad una imagen —
```bash
codex --profile designer -i "$ARTEFACTOS_DIR/base/inicio__escritorio.png" \
  "¿Qué texto se lee en esta imagen? Respondé solo el texto."
```
**Esperado:** responde `stage vivo`.

**Si responde que no puede ver imágenes:** el modelo del alias `designer` no es
multimodal. Cambiarlo en `infra/litellm-config.yaml` por uno de visión y repetir.
Ver [modelos.md](modelos.md#el-diseñador-necesita-visión).

---

### T058 · La vuelta completa
**Ejecuta:** 🤖 · **Depende de:** T057

Con un worktree real, ya sobre el proyecto que se esté desarrollando:

```bash
cd ~/workspace/self-hosted-ai-devops
./scripts/nueva-tarea.sh 2
./scripts/bucle-visual.sh 2 --solo-mirar     # primero sin tocar código
./scripts/bucle-visual.sh 2 --vueltas 1      # después, una vuelta de mejora
```

**Verificación:** llegan al celular las imágenes de antes y después, y
`git -C ~/workspace/worktrees/issue-2-backend log --oneline -1` muestra el commit
de la vuelta.

**Si el bucle revierte:** es el comportamiento correcto cuando la accesibilidad
empeora. La captura de las dos versiones llega igual al celular para que
decidas a mano.

**Si falla:** códigos de salida — `1` empeoró y revirtió, `2` configuración,
`3` el build de la rama se rompió.

---

## Resumen

| Fase | Tareas | 🤖 Agente | 👤 Persona |
|---|---|---|---|
| **00 · El implementador** | **T00A–T00E** | **1** | **4** |
| 0 · Preparación | T001–T004 | — | 4 |
| 1 · VM ESXi | T005–T006 | — | 2 |
| 2 · Ubuntu | T007–T009 | 2 | 1 |
| 3 · Tailscale | T010–T011 | — | 2 |
| 4 · Docker | T012–T013 | 1 | 1 |
| 5 · LiteLLM | T014–T020 | 6 | 1 |
| 6 · Telegram | T021–T023 | — | 3 |
| 7 · OpenClaw | T024–T027 | 1 | 3 |
| 8 · Codex CLI | T028–T031 | 4 | — |
| 9 · GitHub | T032–T039 | 4 | 4 |
| 10 · Flota | T040–T045 | 4 | 2 |
| 11 · Bucle visual | T046–T058 | 10 | 3 |
| **Total** | **63** | **33** | **30** |

Casi la mitad del trabajo requiere una persona: paneles web, apps de celular y decisiones. El agente no puede crear una VM en ESXi ni hablar con BotFather.

La Fase 00 es la única que se hace **fuera de la VM**: instala al Codex que ejecuta todo lo demás. Sus cuatro tareas 👤 son inevitables — nadie puede instalar al implementador salvo vos.

La fase 11 es la más automatizable de todas —diez tareas de trece— porque para entonces ya existe todo lo que necesita: Docker, el gateway, los perfiles y la tailnet.

**Las tres tareas que no se saltean, pase lo que pase:** T003 (topes de gasto), T027 (allowlist verificada desde otra cuenta) y T036 (el hook bloquea de verdad).

**Y una cuarta, si se hace la fase 11:** T054 — un comparador visual que nunca detecta un cambio no está comparando nada, y todo el bucle queda dando siempre por bueno lo que ve.
