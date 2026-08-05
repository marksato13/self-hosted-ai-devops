# Instalación paso a paso

De un ESXi vacío al primer Pull Request abierto desde el celular.

**Tiempo estimado:** 3 a 4 horas repartidas, la mayor parte esperando descargas.
**Requisitos previos:** acceso al ESXi, una cuenta de GitHub, un celular con Telegram.

---

## Índice

| Fase | Qué se logra | Tiempo |
|---|---|---|
| [0](#fase-0--antes-de-empezar) | Reunir cuentas y claves | 30 min |
| [1](#fase-1--crear-la-vm-en-esxi) | VM creada en ESXi | 20 min |
| [2](#fase-2--instalar-ubuntu-server-2404-lts) | Ubuntu Server instalado | 30 min |
| [3](#fase-3--acceso-remoto-con-tailscale) | SSH desde el celular | 15 min |
| [4](#fase-4--docker) | Docker funcionando | 10 min |
| [5](#fase-5--el-bot-de-telegram) | Bot creado con allowlist | 15 min |
| [6](#fase-6--openclaw) | Orquestador respondiendo por Telegram | 30 min |
| [7](#fase-7--codex-cli-y-los-perfiles) | Los 4 perfiles de modelo probados | 40 min |
| [8](#fase-8--github-y-el-primer-pr) | Primer PR abierto desde el celular | 30 min |

---

## Fase 0 — Antes de empezar

Reuní esto primero; frena menos que ir a buscarlo a mitad de camino.

- [ ] ISO de **Ubuntu Server 24.04 LTS** descargada → https://ubuntu.com/download/server
      *(Server, no Desktop — el motivo está en [ADR-006](decisiones.md#adr-006--ubuntu-server-y-no-ubuntu-desktop))*
- [ ] Acceso al panel web del ESXi
- [ ] Cuenta de Tailscale (sirve la gratuita, con login de Google/GitHub)
- [ ] Telegram instalado en el celular
- [ ] Cuenta de GitHub con el repo `self-hosted-ai-devops` creado
- [ ] Claves de API: OpenAI, DeepSeek, Bailian, Zhipu → [modelos.md](modelos.md#dónde-se-saca-cada-clave)
- [ ] **Topes de gasto configurados en la consola de cada proveedor** → [modelos.md](modelos.md#topes-de-gasto)

---

## Fase 1 — Crear la VM en ESXi

Entrá al panel web del ESXi → *Máquinas virtuales* → *Crear/Registrar VM*.

| Parámetro | Valor | Por qué |
|---|---|---|
| Tipo | Crear una VM nueva | |
| Nombre | `ai-devops` | |
| Compatibilidad | ESXi 8.0 U2 o superior | |
| SO invitado | Linux → **Ubuntu Linux (64 bits)** | |
| vCPU | **4** | La licencia gratuita permite hasta 8 |
| RAM | **6 GB** | Docker + Codex trabajan cómodos |
| Disco | **30 GB**, aprovisionamiento fino | Crece según se use |
| Red | **Bridged / VM Network** | La VM toma una IP de tu LAN |
| CD/DVD | Archivo ISO del datastore → la ISO de Ubuntu Server | |

Marcá **"Conectar al encender"** en el CD/DVD, o la VM arrancará sin instalador.

📌 **Snapshot #1** — tomalo con la VM creada y apagada, antes de instalar nada. Es el punto de retorno más barato que vas a tener.

Detalle ampliado en [infra/vm-esxi.md](../infra/vm-esxi.md).

---

## Fase 2 — Instalar Ubuntu Server 24.04 LTS

Encendé la VM y abrí la consola desde el panel del ESXi.

Durante el instalador:

| Pantalla | Qué elegir |
|---|---|
| Idioma / teclado | Español (Latinoamérica) o el que uses |
| Tipo de instalación | **Ubuntu Server** (no la variante *minimized*) |
| Red | Debería tomar IP por DHCP. **Anotá esa IP** |
| Proxy / mirror | Dejar en blanco / por defecto |
| Disco | Usar el disco entero, sin LVM cifrado |
| Perfil | Tu nombre, nombre de host `ai-devops`, usuario y contraseña |
| **Instalar servidor OpenSSH** | ✅ **Sí. No lo omitas** — sin esto no entrás por SSH |
| Snaps destacados | Ninguno |

Reiniciá cuando termine y desconectá la ISO.

Primera entrada por SSH, desde tu PC:

```bash
ssh tu_usuario@IP_DE_LA_VM
```

Actualizá todo:

```bash
sudo apt update && sudo apt -y upgrade
sudo apt -y install git curl ca-certificates ufw
```

Firewall básico (denegar todo lo entrante salvo SSH):

```bash
sudo ufw allow OpenSSH
sudo ufw --force enable
sudo ufw status
```

Esto no rompe nada del proyecto: **todo el tráfico del sistema es saliente** — Telegram por polling, las APIs de modelos y GitHub. Nada necesita entrar.

✅ **Fase 2 lista cuando:** entrás por SSH y `lsb_release -a` muestra Ubuntu 24.04.

---

## Fase 3 — Acceso remoto con Tailscale

Para llegar a la VM desde el celular sin abrir el router.

```bash
curl -fsSL https://tailscale.com/install.sh | sh
sudo tailscale up
```

Te va a mostrar una URL. Abrila en el navegador y autenticá con la misma cuenta que vas a usar en el celular.

```bash
tailscale ip -4     # anotá esta IP: es la de la VM dentro de tu red privada
```

En el celular: instalá la app de Tailscale, entrá con la misma cuenta y activala. Con un cliente SSH (Termius, JuiceSSH) conectate a esa IP.

✅ **Fase 3 lista cuando:** entrás por SSH a la VM **desde datos móviles, con el WiFi apagado**. Esa es la prueba real de que no dependés de estar en casa.

---

## Fase 4 — Docker

```bash
curl -fsSL https://get.docker.com | sh
sudo usermod -aG docker $USER
```

Cerrá la sesión SSH y volvé a entrar (el cambio de grupo no aplica hasta reconectar).

```bash
docker run --rm hello-world
docker compose version
```

📌 **Snapshot #2** — sistema base listo, antes de instalar el stack del proyecto.

✅ **Fase 4 lista cuando:** `hello-world` corre **sin** `sudo`.

---

## Fase 5 — El bot de Telegram

### 5.1 Crear el bot

En Telegram, buscá **@BotFather**:

```
/newbot
→ nombre visible:  AI DevOps
→ usuario:         mi_ai_devops_bot     (debe terminar en "bot")
```

BotFather devuelve un token con la forma `1234567890:AAF...`. **Ese token es una credencial**: quien lo tenga controla el bot.

### 5.2 Obtener tu chat_id

Escribile a **@userinfobot** en Telegram. Te responde con tu ID numérico.

### 5.3 🔴 La allowlist — no saltear este paso

Un bot de Telegram es **público por definición**. Cualquiera que descubra su nombre de usuario puede escribirle, y si el bot ejecuta comandos en tu VM, esa persona tiene shell en tu máquina — con tu token de GitHub y tus cuatro claves de API adentro.

La allowlist es lo que lo impide:

```bash
cd ~/self-hosted-ai-devops
cp .env.example .env
chmod 600 .env
nano .env
```

Completá al menos:

```env
TELEGRAM_BOT_TOKEN=1234567890:AAF...
TELEGRAM_ALLOWED_CHAT_IDS=123456789      # tu chat_id, y nadie más
```

✅ **Fase 5 lista cuando:** el bot existe y tu `chat_id` está en el `.env`. La verificación real es en la Fase 6.

---

## Fase 6 — OpenClaw

> ⚠️ Los nombres de imagen y variables de OpenClaw **deben confirmarse en su documentación oficial**. El compose de este repo es una plantilla parametrizada, no una configuración probada.

Completá en `.env` la imagen oficial que indique la documentación:

```env
OPENCLAW_IMAGE=<imagen oficial de OpenClaw>
```

Levantalo:

```bash
cd ~/self-hosted-ai-devops
docker compose -f infra/docker-compose.yml up -d
docker compose -f infra/docker-compose.yml logs -f
```

### Las dos pruebas de la allowlist

1. **Desde tu cuenta:** escribile `hola` al bot → debe responder.
2. **Desde otra cuenta** (pedile a alguien, o usá una segunda cuenta): escribile → **debe ser ignorado**, y debería quedar registro en los logs.

Si la segunda prueba **no** falla como se espera, apagá el contenedor y arreglá la allowlist antes de seguir:

```bash
docker compose -f infra/docker-compose.yml down
```

✅ **Fase 6 lista cuando:** pasan las dos pruebas. Las dos, no solo la primera.

---

## Fase 7 — Codex CLI y los perfiles

### 7.1 Instalar

```bash
sudo apt -y install nodejs npm
npm i -g @openai/codex
codex --version
```

### 7.2 Configurar los perfiles

```bash
mkdir -p ~/.codex
cp config/codex-config.toml.example ~/.codex/config.toml
chmod 600 ~/.codex/config.toml
nano ~/.codex/config.toml
```

Ajustá `base_url` y los nombres de modelo según lo que confirmes en [modelos.md](modelos.md).

### 7.3 Exportar las claves

```bash
set -a && source ~/self-hosted-ai-devops/.env && set +a
```

Para que persista entre sesiones, agregá esa línea al final de `~/.bashrc`.

### 7.4 Probar los cuatro perfiles, uno por uno

```bash
codex --profile openai   "responde solo: ok"
codex --profile deepseek "responde solo: ok"
codex --profile qwen     "responde solo: ok"
codex --profile glm      "responde solo: ok"
```

Probalos **por separado**. Si uno falla, es un problema de ese proveedor —clave, endpoint o nombre de modelo— y se arregla solo. Probarlos todos juntos convierte cuatro problemas simples en uno confuso.

✅ **Fase 7 lista cuando:** los cuatro perfiles responden.

---

## Fase 8 — GitHub y el primer PR

### 8.1 Token de alcance mínimo

En GitHub → *Settings → Developer settings → Personal access tokens → Fine-grained*:

| Campo | Valor |
|---|---|
| Repository access | **Only select repositories** → `self-hosted-ai-devops` |
| Contents | Read and write |
| Pull requests | Read and write |
| Metadata | Read |
| Todo lo demás | Sin acceso |

Nada de tokens clásicos con scope `repo` completo: eso da acceso a **todos** tus repositorios.

Guardalo en `.env` como `GITHUB_TOKEN` y configurá git en la VM:

```bash
git config --global user.name  "AI DevOps Bot"
git config --global user.email "bot@localhost"
gh auth login --with-token <<< "$GITHUB_TOKEN"    # si usás gh CLI
```

### 8.2 Proteger `main`

En GitHub → *Settings → Branches → Add rule* sobre `main`:

- [x] Require a pull request before merging
- [x] Do not allow bypassing the above settings
- [ ] *(opcional)* Require status checks to pass

Esto es lo que garantiza que ningún agente escriba en la rama principal ([ADR-009](decisiones.md#adr-009--el-merge-lo-aprueba-una-persona)).

### 8.3 Clonar el workspace

```bash
mkdir -p ~/workspace && cd ~/workspace
git clone https://github.com/marksato13/self-hosted-ai-devops.git
```

### 8.4 La prueba de fuego

Desde el celular, por Telegram:

```
corrige el typo de la línea 3 del README y abre un PR
```

Lo que debería pasar: OpenClaw toma el mensaje → Codex (perfil `openai`) crea una rama, edita y pushea → se abre un PR → te llega el link por Telegram.

📌 **Snapshot #3** — stack completo funcionando.

✅ **Fase 8 lista cuando:** recibís el link de un PR en el celular sin haber tocado la PC.

---

## Después de la Fase 8

Con un agente funcionando, la flota completa es la Fase 5 del [plan general](../README.md#fases-y-criterios-de-aceptación): sumar los perfiles `deepseek`, `qwen` y `glm` y el flujo planificador → paralelo → revisor descrito en [arquitectura.md](arquitectura.md).

Para el día a día y los problemas comunes: [runbook.md](runbook.md).

---

## Si algo falla

| Síntoma | Dónde mirar |
|---|---|
| No entra el SSH | ¿Instalaste OpenSSH en la Fase 2? ¿`ufw allow OpenSSH`? |
| Tailscale no conecta desde el celular | ¿Misma cuenta en ambos lados? ¿`sudo tailscale up` corrió? |
| `docker` pide `sudo` | Falta reconectar la sesión SSH tras el `usermod` |
| El bot no responde | `docker compose logs -f`; revisá el token en `.env` |
| El bot responde a desconocidos | 🔴 Pará todo. `TELEGRAM_ALLOWED_CHAT_IDS` mal configurado |
| Un perfil de Codex falla | Clave, `base_url` o nombre de modelo. Probalo aislado |
| `git push` rechazado | El token no tiene permiso de escritura sobre el repo |

Diagnóstico ampliado en [runbook.md](runbook.md#diagnóstico).
