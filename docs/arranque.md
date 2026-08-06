# Arranque manual

Los comandos que corrés **a mano** en la VM, desde Ubuntu recién instalado hasta que Codex CLI puede tomar el control y ejecutar el resto del plan solo.

Es el único tramo que no se automatiza: no hay agente todavía que lo haga.

> **Este documento se lee desde GitHub**, porque el repositorio todavía no está clonado en la VM. Cuando llegues al paso 7 ya lo tenés local.

---

## Dónde corrés cada cosa

| Paso | Ruta | Por qué |
|---|---|---|
| 1 – 6 | Cualquiera. Usá `cd ~` | Son comandos de sistema: `apt`, `ufw`, `tailscale`, `docker` |
| 7 – 9 | `~` y después `~/self-hosted-ai-devops` | Acá aparece el repositorio |
| 10 | `~/self-hosted-ai-devops` | Desde donde le hablás a Codex |

Después del paso 10 manda el plan, y cada tarea dice su propia ruta.

---

## 0. Salí de root

Si tu prompt dice `root@ubuntu:…#`, pará acá.

El plan **no está escrito para root**, y el síntoma aparece tarde:

- `verificar.sh` usa `$HOME`. Como root es `/root`; como tu usuario, `/home/<usuario>`. Clonar con uno y verificar con el otro da **FALLA en todo** sin que nada esté roto.
- El paso 6 hace `sudo usermod -aG docker $USER`. Como root eso no hace nada útil, y después `docker` sin `sudo` falla.
- Todo lo que crees queda **propiedad de root** dentro de la casa de tu usuario.

```bash
# Como root, una sola vez (cambiá m4rk por tu usuario):
usermod -aG sudo m4rk
su - m4rk
```

El guion de `su - m4rk` **no es opcional**: sin él, `$HOME` sigue apuntando a `/root`.

**Verificación:**

```bash
whoami        # tu usuario, no root
echo $HOME    # /home/<tu usuario>
sudo -v       # pide contraseña y no da error
```

A partir de acá, nunca más root. Cuando haga falta privilegio, se usa `sudo` explícito.

---

## 1. Sistema y utilidades · T008

```bash
sudo apt update && sudo apt -y upgrade
sudo apt -y install git curl ca-certificates ufw jq openssl
```

**Verificación:**
```bash
command -v git curl jq openssl >/dev/null && echo OK
```

`jq` y `openssl` no son opcionales: los scripts del proyecto los usan para leer JSON y generar las claves internas.

---

## 2. Firewall · T009

```bash
sudo ufw allow OpenSSH
sudo ufw --force enable
```

**Verificación:**
```bash
sudo ufw status | grep -q "Status: active" && echo OK
```

No rompe nada: todo el tráfico del sistema es **saliente** — polling de Telegram, APIs de modelos, GitHub. Nada entra desde internet.

**Si falla:** no sigas sin firewall. Revisá `sudo ufw status verbose`.

---

## 3. Tailscale · T010

```bash
curl -fsSL https://tailscale.com/install.sh | sh
sudo tailscale up --ssh
```

Imprime una URL. Abrila **en tu PC o celular** e iniciá sesión con la cuenta de Tailscale.

**Verificación:**
```bash
tailscale status | head -3
tailscale ip -4
```

Anotá esa IP: es por donde vas a entrar desde el celular.

---

## 4. Probar el acceso desde el celular · T011 👤

Instalá la app de Tailscale en el celular, iniciá sesión con la misma cuenta y conectá. Después, desde una app de SSH (Termius, JuiceSSH):

```
ssh <tu usuario>@<la IP de tailscale>
```

**Verificación:** entrás sin estar en la misma red WiFi. Probá con datos móviles, no con el WiFi de casa — si estás en la misma red podría estar funcionando por la LAN y no por Tailscale.

**Por qué importa ahora:** es lo que te deja arreglar la VM desde el celular cuando algo falle a las 3 de la mañana. Si lo dejás para después, nunca lo probás.

---

## 5. Docker · T012

```bash
curl -fsSL https://get.docker.com | sh
sudo usermod -aG docker $USER
```

🔴 **Ahora cerrá la sesión SSH y volvé a entrar.** El cambio de grupo no aplica hasta reconectar.

```bash
exit
# …volvés a entrar por SSH…
```

**Verificación:**
```bash
docker run --rm hello-world >/dev/null 2>&1 && docker compose version >/dev/null && echo OK
```

**Esperado:** `OK`, **sin usar `sudo`**. Si te pide `sudo`, no reconectaste la sesión.

---

## 6. Snapshot #2 · T013 👤

En el panel del ESXi: *Acciones → Instantáneas → Tomar instantánea*, nombre `02-ubuntu-docker-tailscale`.

**Por qué acá:** es el último punto donde todavía no hay secretos ni configuración propia. Si más adelante rompés el stack, volvés a este snapshot en segundos en vez de reinstalar Ubuntu.

---

## 7. Node.js y Codex CLI

Este es el Codex que va a **ejecutar el resto del plan**.

```bash
curl -fsSL https://deb.nodesource.com/setup_22.x | sudo -E bash -
sudo apt-get install -y nodejs
sudo npm i -g @openai/codex
```

**Verificación:**
```bash
node --version    # v22 o superior
codex --version
```

**Si falla `npm` con `EACCES`:** no lo arregles repitiendo `sudo npm`. Configurá un prefijo propio:

```bash
npm config set prefix ~/.npm-global
echo 'export PATH=~/.npm-global/bin:$PATH' >> ~/.bashrc && source ~/.bashrc
```

---

## 8. Autenticar Codex en una VM sin navegador

`codex login` abre un navegador. En un servidor headless no hay ninguno, así que hace falta un rodeo.

```bash
codex login
```

Imprime una URL y se queda esperando una respuesta en un puerto **local de la VM**. Copiar la URL al navegador de tu PC no alcanza: la respuesta tiene que volver a la VM.

La forma que funciona es un túnel SSH. **Desde tu PC**, en otra terminal:

```bash
ssh -L <puerto>:localhost:<puerto> <tu usuario>@<IP de tailscale>
```

Donde `<puerto>` es el que aparece en la URL que imprimió `codex login` (algo como `http://localhost:1455/...`). Con el túnel abierto, pegás esa misma URL en el navegador de tu PC y el flujo se completa.

**Verificación:**
```bash
codex "responde solo con la palabra: ok"
```

**Esperado:** responde `ok`. Eso prueba tres cosas de una vez: el binario corre, la sesión es válida y hay cuota.

> ⚠️ Los subcomandos y puertos de `codex login` cambian entre versiones. Si algo no coincide con lo de arriba, confirmá con `codex --help` antes de improvisar.

> 💡 Esto usa tu **suscripción de ChatGPT Plus**, no las claves de API. Las cuatro claves son para la flota, no para el implementador.

---

## 9. Clonar el repositorio

```bash
cd ~
git clone https://github.com/marksato13/self-hosted-ai-devops.git
cd ~/self-hosted-ai-devops
chmod +x scripts/*.sh
```

**Verificación:**
```bash
./scripts/verificar.sh 0
```

Va a mostrar las cuatro tareas de la Fase 0 como `manual`. Eso está bien: son tuyas.

---

## 10. Pasarle el control a Codex

Desde `~/self-hosted-ai-devops`:

```bash
codex
```

Y el mensaje de traspaso:

```
Implementá este proyecto siguiendo docs/plan-ejecucion.md.

Reglas:
- Leé primero el "Contrato de ejecución" al principio de ese archivo y respetalo.
- Empezá por T008 y seguí en orden.
- No ejecutes tareas marcadas 👤: pará, mostrame las instrucciones y esperá
  a que te confirme.
- Verificá cada fase con ./scripts/verificar.sh <n> antes de pasar a la siguiente.
- Marcá el avance en ESTADO.md a medida que terminás cada tarea.
- Si una verificación falla dos veces, pará y reportá. No improvises otra solución.

Los pasos 0 a 9 de docs/arranque.md ya están hechos.
```

A partir de acá, tu trabajo es responder a las tareas 👤 y aprobar lo que Codex proponga.

---

## Los dos Codex de este proyecto

Confundirlos es lo que más tiempo cuesta después, porque los síntomas aparecen recién en la Fase 8.

| | **El implementador** (paso 7) | **El de la flota** (T028–T031) |
|---|---|---|
| Se autentica con | Tu suscripción ChatGPT Plus | Una clave virtual de LiteLLM |
| Cómo se invoca | `codex "…"` — perfil por defecto | `codex --profile backend "…"` |
| Para qué sirve | Montar este sistema | Escribir código en el repositorio objetivo |

Son el **mismo binario** con dos configuraciones. T029 agrega los perfiles a `~/.codex/config.toml`, y eso **no rompe** al implementador: los perfiles solo se usan si los pedís con `--profile`. Sin esa bandera seguís yendo por la suscripción.

---

## Los dos clones del repositorio

También hay dos, y tampoco es un error:

```
~/self-hosted-ai-devops            ← la INFRAESTRUCTURA que corre la flota
                                      .env, docker compose, LiteLLM, OpenClaw

~/workspace/self-hosted-ai-devops  ← el REPOSITORIO sobre el que la flota trabaja
                                      worktrees, ramas, PRs
```

El primero lo creás vos en el paso 9 y los agentes no lo tocan nunca. El segundo lo crea **T037**, y es la mesa de trabajo: al lado se arman los worktrees (`~/workspace/worktrees/issue-12-backend`).

Que sea el mismo proyecto en los dos lados es solo porque este repo se usa como conejillo de indias en la Fase 10. Cuando apuntes la flota a otro proyecto, el segundo clon será ese otro.

---

## Resumen

| Paso | Tarea | Quién |
|---|---|---|
| 0 | Salir de root | 👤 |
| 1 | Sistema y utilidades | T008 |
| 2 | Firewall | T009 |
| 3 | Tailscale | T010 |
| 4 | Probar desde el celular | T011 👤 |
| 5 | Docker (+ reconectar) | T012 |
| 6 | Snapshot #2 | T013 👤 |
| 7 | Node y Codex CLI | — |
| 8 | `codex login` por túnel SSH | 👤 |
| 9 | Clonar el repositorio | T014 |
| 10 | Traspaso a Codex | 👤 |

Sigue en [plan-ejecucion.md](plan-ejecucion.md), Fase 5.
