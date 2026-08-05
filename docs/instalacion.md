# Instalación paso a paso

De un ESXi vacío a una flota de cinco agentes abriendo Pull Requests desde el celular.

**Tiempo estimado:** 5 a 6 horas repartidas, la mayor parte esperando descargas.
**Requisitos previos:** acceso al ESXi, una cuenta de GitHub, un celular con Telegram.

Cada fase termina con un **criterio verificable**. Si no se cumple, no pases a la siguiente: los errores de infraestructura se acumulan y después no se sabe cuál rompió qué.

---

## Índice

| Fase | Qué se logra | Tiempo |
|---|---|---|
| [0](#fase-0--antes-de-empezar) | Reunir cuentas y claves | 30 min |
| [1](#fase-1--crear-la-vm-en-esxi) | VM creada en ESXi | 20 min |
| [2](#fase-2--instalar-ubuntu-server-2404-lts) | Ubuntu Server instalado | 30 min |
| [3](#fase-3--acceso-remoto-con-tailscale) | SSH desde el celular | 15 min |
| [4](#fase-4--docker) | Docker funcionando | 10 min |
| [5](#fase-5--litellm-el-gateway-de-modelos) | Los 4 modelos accesibles por un endpoint | 40 min |
| [6](#fase-6--el-bot-de-telegram) | Bot creado con allowlist verificada | 20 min |
| [7](#fase-7--openclaw) | Orquestador respondiendo por Telegram | 30 min |
| [8](#fase-8--codex-cli-y-los-perfiles) | Los 5 perfiles de agente probados | 30 min |
| [9](#fase-9--github-guardarraíles-y-primer-pr) | Primer PR abierto desde el celular | 40 min |
| [10](#fase-10--la-flota-completa) | 3 agentes en paralelo → 1 PR consolidado | 60 min |

---

## Fase 0 — Antes de empezar

Reuní esto primero; frena menos que ir a buscarlo a mitad de camino.

- [ ] ISO de **Ubuntu Server 24.04 LTS** → https://ubuntu.com/download/server
      *(Server, no Desktop — el motivo está en [ADR-006](decisiones.md#adr-006--ubuntu-server-y-no-ubuntu-desktop))*
- [ ] Acceso al panel web del ESXi
- [ ] Cuenta de Tailscale (sirve la gratuita, con login de Google/GitHub)
- [ ] Telegram instalado en el celular
- [ ] Cuenta de GitHub con el repo `self-hosted-ai-devops`
- [ ] Claves de API: OpenAI, DeepSeek, Bailian, Zhipu → [modelos.md](modelos.md#dónde-se-saca-cada-clave)
- [ ] **Topes de gasto configurados en la consola de cada proveedor** → [modelos.md](modelos.md#topes-de-gasto)

---

## Fase 1 — Crear la VM en ESXi

Panel web del ESXi → *Máquinas virtuales* → *Crear/Registrar VM*.

| Parámetro | Valor | Por qué |
|---|---|---|
| Tipo | Crear una VM nueva | |
| Nombre | `ai-devops` | |
| Compatibilidad | ESXi 8.0 U2 o superior | |
| SO invitado | Linux → **Ubuntu Linux (64 bits)** | |
| vCPU | **4** | La licencia gratuita permite hasta 8 |
| RAM | **6 GB** | Docker (3 contenedores) + Codex trabajan cómodos |
| Disco | **30 GB**, aprovisionamiento fino | Crece según se use |
| Red | **Bridged / VM Network** | La VM toma una IP de tu LAN |
| CD/DVD | Archivo ISO del datastore → la ISO de Ubuntu Server | |

Marcá **"Conectar al encender"** en el CD/DVD, o la VM arranca sin instalador.

📌 **Snapshot #1** — con la VM creada y apagada, antes de instalar nada.

Detalle ampliado en [infra/vm-esxi.md](../infra/vm-esxi.md).

---

## Fase 2 — Instalar Ubuntu Server 24.04 LTS

Encendé la VM y abrí la consola desde el panel del ESXi.

| Pantalla del instalador | Qué elegir |
|---|---|
| Idioma / teclado | Español (Latinoamérica) o el que uses |
| Tipo de instalación | **Ubuntu Server** (no la variante *minimized*) |
| Red | Debería tomar IP por DHCP. **Anotá esa IP** |
| Proxy / mirror | En blanco / por defecto |
| Disco | Usar el disco entero, sin LVM cifrado |
| Perfil | Tu nombre, host `ai-devops`, usuario y contraseña |
| **Instalar servidor OpenSSH** | ✅ **Sí. No lo omitas** — sin esto no entrás por SSH |
| Snaps destacados | Ninguno |

Reiniciá y desconectá la ISO. Primera entrada por SSH desde tu PC:

```bash
ssh tu_usuario@IP_DE_LA_VM
```

Actualizar e instalar lo básico:

```bash
sudo apt update && sudo apt -y upgrade
sudo apt -y install git curl ca-certificates ufw jq
```

Firewall (denegar todo lo entrante salvo SSH):

```bash
sudo ufw allow OpenSSH
sudo ufw --force enable
sudo ufw status
```

Esto no rompe nada: **todo el tráfico del sistema es saliente** — Telegram por polling, las APIs de modelos y GitHub. Nada necesita entrar.

✅ **Fase 2 lista cuando:** entrás por SSH y `lsb_release -a` muestra Ubuntu 24.04.

---

## Fase 3 — Acceso remoto con Tailscale

```bash
curl -fsSL https://tailscale.com/install.sh | sh
sudo tailscale up
```

Te muestra una URL: abrila y autenticá con la misma cuenta que vas a usar en el celular.

```bash
tailscale ip -4     # anotá esta IP: la de la VM en tu red privada
```

En el celular: instalá la app de Tailscale, entrá con la misma cuenta y activala. Con un cliente SSH (Termius, JuiceSSH) conectate a esa IP.

✅ **Fase 3 lista cuando:** entrás por SSH **desde datos móviles, con el WiFi apagado**. Esa es la prueba real de que no dependés de estar en casa.

---

## Fase 4 — Docker

```bash
curl -fsSL https://get.docker.com | sh
sudo usermod -aG docker $USER
```

Cerrá la sesión SSH y volvé a entrar — el cambio de grupo no aplica hasta reconectar.

```bash
docker run --rm hello-world
docker compose version
```

📌 **Snapshot #2** — sistema base listo, antes del stack del proyecto.

✅ **Fase 4 lista cuando:** `hello-world` corre **sin** `sudo`.

---

## Fase 5 — LiteLLM, el gateway de modelos

> Esta fase no estaba en el plan original. Se agregó porque **sin ella tres de los cinco agentes no funcionan**: Codex CLI solo habla la Responses API y DeepSeek, Qwen y GLM solo hablan Chat Completions. LiteLLM traduce entre ambas, y de paso aplica los topes de gasto. Ver [ADR-010](decisiones.md#adr-010--litellm-como-gateway-de-modelos).

### 5.1 Clonar el repo y preparar los secretos

```bash
cd ~
git clone https://github.com/marksato13/self-hosted-ai-devops.git
cd self-hosted-ai-devops
cp .env.example .env
chmod 600 .env
```

Generá las dos claves internas:

```bash
echo "LITELLM_MASTER_KEY=sk-$(openssl rand -hex 24)"
echo "POSTGRES_PASSWORD=$(openssl rand -hex 16)"
```

Copiá esas dos líneas al `.env`, junto con las cuatro claves de proveedor:

```bash
nano .env
```

### 5.2 Levantar el gateway

```bash
docker compose -f infra/docker-compose.yml up -d postgres litellm
docker compose -f infra/docker-compose.yml logs -f litellm
```

### 5.3 Probar cada modelo, uno por uno

```bash
set -a && source .env && set +a

curl -s http://localhost:4000/health/liveliness

for m in planner backend tester docs reviewer; do
  echo "── $m ──"
  curl -s http://localhost:4000/v1/chat/completions \
    -H "Authorization: Bearer $LITELLM_MASTER_KEY" \
    -H "Content-Type: application/json" \
    -d "{\"model\":\"$m\",\"messages\":[{\"role\":\"user\",\"content\":\"responde solo: ok\"}]}" \
    | jq -r '.choices[0].message.content // .error.message'
done
```

Si uno falla, es problema **de ese proveedor**: clave, `api_base` o nombre de modelo. Se arregla en `infra/litellm-config.yaml` y se reinicia con `docker compose restart litellm`.

Errores frecuentes → [modelos.md](modelos.md#si-un-modelo-se-descontinúa) y [runbook.md](runbook.md#un-perfil-de-codex-falla).

### 5.4 Claves virtuales con presupuesto por agente

Esto es lo que hace que un agente en bucle queme **su** presupuesto y se detenga solo, sin arrastrar a los demás:

```bash
for a in planner backend tester docs reviewer; do
  curl -s -X POST http://localhost:4000/key/generate \
    -H "Authorization: Bearer $LITELLM_MASTER_KEY" \
    -H "Content-Type: application/json" \
    -d "{\"models\":[\"$a\"],\"max_budget\":5,\"budget_duration\":\"30d\",\"key_alias\":\"agente-$a\"}" \
    | jq -r '"\(.key_alias): \(.key)"'
done
```

Guardá esas claves: son las que van a usar los agentes en la Fase 8.

✅ **Fase 5 lista cuando:** los cinco modelos responden `ok` y las claves virtuales existen.

---

## Fase 6 — El bot de Telegram

### 6.1 Crear el bot

En Telegram, buscá **@BotFather**:

```
/newbot
→ nombre visible:  AI DevOps
→ usuario:         algo_poco_adivinable_bot     (debe terminar en "bot")
```

Devuelve un token con la forma `1234567890:AAF...`. **Es una credencial**: quien lo tenga controla el bot.

### 6.2 Obtener tu chat_id

Escribile a **@userinfobot**. Te responde con tu ID numérico.

### 6.3 🔴 La allowlist — no saltear

Un bot de Telegram es **público por definición**. Cualquiera que descubra su usuario puede escribirle, y si el bot ejecuta comandos en tu VM, esa persona tiene shell en tu máquina — con tu token de GitHub y tus claves adentro.

```bash
nano ~/self-hosted-ai-devops/.env
```

```env
TELEGRAM_BOT_TOKEN=1234567890:AAF...
TELEGRAM_ALLOWED_CHAT_IDS=123456789      # tu chat_id, y nadie más
```

✅ **Fase 6 lista cuando:** el bot existe y tu `chat_id` está en el `.env`. La verificación real es en la Fase 7.

---

## Fase 7 — OpenClaw

> ⚠️ El nombre de la imagen y las variables de OpenClaw **deben confirmarse en su documentación oficial**. El compose de este repo es una plantilla parametrizada, no una configuración probada.

```bash
nano ~/self-hosted-ai-devops/.env    # completar OPENCLAW_IMAGE
cd ~/self-hosted-ai-devops
docker compose -f infra/docker-compose.yml up -d
docker compose -f infra/docker-compose.yml logs -f openclaw
```

### Las dos pruebas de la allowlist

1. **Desde tu cuenta:** escribile `hola` al bot → debe responder.
2. **Desde otra cuenta** (pedile a alguien, o usá una segunda cuenta): escribile → **debe ser ignorado**, y debería quedar registro en los logs.

Si la segunda prueba **no** falla como se espera, apagá todo y arreglá la allowlist antes de seguir:

```bash
docker compose -f infra/docker-compose.yml down
```

✅ **Fase 7 lista cuando:** pasan **las dos** pruebas. Las dos, no solo la primera.

---

## Fase 8 — Codex CLI y los perfiles

### 8.1 Instalar

```bash
sudo apt -y install nodejs npm
npm i -g @openai/codex
codex --version
```

### 8.2 Configurar los perfiles

```bash
mkdir -p ~/.codex
cp ~/self-hosted-ai-devops/config/codex-config.toml.example ~/.codex/config.toml
chmod 600 ~/.codex/config.toml
```

Los cinco perfiles apuntan al **mismo** proveedor (`gateway` → LiteLLM en `localhost:4000`). Lo que cambia entre ellos es el alias de modelo, y ese alias se resuelve en `litellm-config.yaml`. Cambiar de modelo más adelante no toca este archivo.

```bash
set -a && source ~/self-hosted-ai-devops/.env && set +a
echo 'set -a && source ~/self-hosted-ai-devops/.env && set +a' >> ~/.bashrc
```

### 8.3 Probar los cinco perfiles por separado

```bash
for p in planner backend tester docs reviewer; do
  echo "── $p ──"
  codex --profile "$p" "responde solo: ok"
done
```

Probalos **uno por uno**. Si uno falla, es problema de ese perfil y se arregla solo; probarlos todos juntos convierte cinco problemas simples en uno confuso.

✅ **Fase 8 lista cuando:** los cinco perfiles responden.

---

## Fase 9 — GitHub, guardarraíles y primer PR

### 9.1 Token de alcance mínimo

GitHub → *Settings → Developer settings → Personal access tokens → Fine-grained*:

| Campo | Valor |
|---|---|
| Repository access | **Only select repositories** → `self-hosted-ai-devops` |
| Contents | Read and write |
| Pull requests | Read and write |
| Metadata | Read |
| Todo lo demás | Sin acceso |

Nada de tokens clásicos con scope `repo` completo: eso da acceso a **todos** tus repositorios.

```bash
nano ~/self-hosted-ai-devops/.env      # GITHUB_TOKEN=...
git config --global user.name  "AI DevOps Bot"
git config --global user.email "bot@localhost"
sudo apt -y install gh
gh auth login --with-token <<< "$GITHUB_TOKEN"
```

### 9.2 Proteger `main`

GitHub → *Settings → Branches → Add rule* sobre `main`:

- [x] Require a pull request before merging
- [x] Do not allow bypassing the above settings

Es lo que garantiza que ningún agente escriba en la rama principal ([ADR-009](decisiones.md#adr-009--el-merge-lo-aprueba-una-persona)).

### 9.3 🔴 Guardarraíles de commit

Los commits asistidos por IA filtran secretos a aproximadamente **el doble** de la tasa humana (GitGuardian, marzo de 2026). El repo es público y la máquina tiene cinco credenciales. Esto no es opcional.

```bash
sudo apt -y install pipx
pipx install pre-commit
pipx ensurepath && source ~/.bashrc

# Gitleaks
GL=8.28.0
curl -sSL "https://github.com/gitleaks/gitleaks/releases/download/v${GL}/gitleaks_${GL}_linux_x64.tar.gz" \
  | sudo tar -xz -C /usr/local/bin gitleaks

cd ~/self-hosted-ai-devops
pre-commit install
pre-commit run --all-files
```

Probá que realmente bloquea:

```bash
echo 'OPENAI_API_KEY=sk-proj-falsaparaprobar1234567890abcdef' > prueba.txt
git add prueba.txt && git commit -m "prueba"   # ← debe FALLAR
rm prueba.txt && git reset
```

Si el commit pasa, el hook no está activo. Arreglalo antes de seguir.

### 9.4 Preparar el workspace

```bash
mkdir -p ~/workspace && cd ~/workspace
git clone https://github.com/marksato13/self-hosted-ai-devops.git
chmod +x ~/workspace/self-hosted-ai-devops/scripts/*.sh
```

### 9.5 La prueba de fuego

Desde el celular, por Telegram:

```
corrige el typo de la línea 3 del README y abre un PR
```

Debería pasar: OpenClaw toma el mensaje → Codex (perfil `planner`) crea una rama, edita y pushea → se abre un PR → te llega el link por Telegram.

📌 **Snapshot #3** — un agente funcionando de punta a punta.

✅ **Fase 9 lista cuando:** recibís el link de un PR en el celular sin haber tocado la PC.

---

## Fase 10 — La flota completa

Un agente ya funciona. Ahora los cinco, con los tres del medio en paralelo.

### 10.1 Probar los worktrees a mano

Antes de automatizarlo, corré el flujo manualmente una vez. Entender qué hace cada paso vale más que un script que funciona por razones que no conocés.

```bash
cd ~/workspace/self-hosted-ai-devops
./scripts/nueva-tarea.sh 1
```

Crea tres worktrees, uno por agente, cada uno en su rama, todos compartiendo un solo `.git` ([ADR-011](decisiones.md#adr-011--git-worktrees-no-clones-por-agente)):

```
~/workspace/worktrees/
├── issue-1-backend/     → feat/issue-1-backend
├── issue-1-tests/       → test/issue-1
└── issue-1-docs/        → docs/issue-1
```

```bash
git worktree list      # los tres, más el principal
```

### 10.2 Correr los tres agentes en paralelo

Cada uno en su worktree, con su perfil. Los prompts de sistema completos están en [agentes.md](agentes.md).

```bash
WT=~/workspace/worktrees

(cd $WT/issue-1-backend && codex --profile backend "…subtarea backend…") &
(cd $WT/issue-1-tests   && codex --profile tester  "…subtarea tests…")   &
(cd $WT/issue-1-docs    && codex --profile docs    "…subtarea docs…")    &
wait
```

Que no se pisen es todo el punto: cada uno escribe en su propio directorio y su propia rama.

### 10.3 Integrar y abrir el PR

```bash
cd ~/workspace/self-hosted-ai-devops
./scripts/integrar.sh 1
```

El script hace el trabajo del Revisor: une las tres ramas en `integra/issue-1` (**local, sin pasar por GitHub**, porque los worktrees comparten repositorio), corre gitleaks y los tests, y abre **un solo PR en borrador**.

Los códigos de salida dicen qué falló:

| Código | Significa |
|---|---|
| 2 | Conflicto de merge — el Revisor debe resolverlo o escalar |
| 3 | 🔴 Secreto detectado — no se abre el PR |
| 4 | Tests fallaron — vuelve al agente correspondiente |
| 5 | `docker-compose` inválido |

El PR sale en **borrador** a propósito: refuerza que nada se mergea solo.

### 10.4 Limpiar

```bash
./scripts/limpiar-worktrees.sh 1
```

Borra los worktrees y las ramas ya integradas. Sin esto, `~/worktrees` se llena y el disco de 30 GB se acaba. Avisa antes de borrar si quedó trabajo sin commitear.

### 10.5 Conectarlo a OpenClaw

El último paso es que OpenClaw dispare esta secuencia al recibir un mensaje, en vez de hacerla vos a mano:

1. `codex --profile planner` → plan en JSON con las subtareas
2. `./scripts/nueva-tarea.sh <issue>`
3. Los tres agentes en paralelo, uno por worktree
4. `./scripts/integrar.sh <issue>`
5. Mandar el link del PR por Telegram
6. `./scripts/limpiar-worktrees.sh <issue>` al aprobar

> **Pendiente de resolver:** si OpenClaw puede invocar estos comandos directamente o hace falta un wrapper. Se define acá, con el sistema ya funcionando a mano — que es el momento correcto para decidirlo.

✅ **Fase 10 lista cuando:** una tarea mandada por Telegram genera tres ramas y **un solo** PR consolidado, sin que toques la PC.

---

## Si algo falla

| Síntoma | Dónde mirar |
|---|---|
| No entra el SSH | ¿Instalaste OpenSSH en la Fase 2? ¿`ufw allow OpenSSH`? |
| Tailscale no conecta desde el celular | ¿Misma cuenta en ambos lados? ¿Corrió `sudo tailscale up`? |
| `docker` pide `sudo` | Falta reconectar la sesión SSH tras el `usermod` |
| LiteLLM no levanta | `docker compose logs litellm`. Suele ser `DATABASE_URL` o Postgres sin arrancar |
| Un modelo da 404 en LiteLLM | El nombre del modelo cambió → [modelos.md](modelos.md#si-un-modelo-se-descontinúa) |
| Un modelo da 401 | Clave mal copiada, o la variable no llegó al contenedor |
| El bot no responde | `docker compose logs -f openclaw`; revisá el token |
| El bot responde a desconocidos | 🔴 Pará todo. `TELEGRAM_ALLOWED_CHAT_IDS` mal configurado |
| Codex da error de `wire_api` | Debe ser `"responses"` y apuntar al gateway, no al proveedor |
| `git push` rechazado sobre `main` | **Está bien**: `main` está protegida. Hay que ir por un PR |
| `worktree add` dice que la rama existe | Ya hay una tarea con ese número. Limpiala primero |

Diagnóstico ampliado en [runbook.md](runbook.md#diagnóstico).
