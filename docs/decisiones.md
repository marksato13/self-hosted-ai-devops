# Decisiones de arquitectura (ADR)

Cada decisión con su contexto, la alternativa descartada y el motivo. Sirve para no volver a discutir lo mismo dentro de seis meses.

---

## ADR-001 — Hardware propio, no nube

**Contexto:** se evaluó levantar todo en AWS con un presupuesto de $50.

**Decisión:** correr en el hipervisor VMware ESXi que ya se tiene en casa.

**Por qué:**
- Una instancia con GPU en AWS parte de ~$0.50/hora. Corriendo continuo, agota los $50 en pocos días.
- El hardware propio está ocioso y sobrado: hay 8,5 GHz de CPU libres, 21 GB de RAM libres y 258 GB de disco libre.
- El presupuesto liberado se reasigna a créditos de API, que es donde el gasto sí produce valor.

**A cambio se acepta:** si se corta la luz o el internet de casa, la flota se cae. Aceptable para un proyecto personal.

---

## ADR-002 — VMware ESXi como hipervisor

**Decisión:** ESXi 8.0 Update 3e, licencia gratuita de Broadcom, sin vCenter.

**Por qué:** ya está instalado y funcionando. La licencia gratuita limita a 8 vCPU por VM, muy por encima de las 4 que se necesitan. Los snapshots permiten revertir un cambio de configuración en segundos.

**Alternativas descartadas:** Proxmox (implicaría reinstalar el host sin ganar nada), Docker sobre Windows en la PC de escritorio (obligaría a tener la PC prendida siempre).

---

## ADR-003 — OpenClaw como orquestador

**Decisión:** OpenClaw es la puerta de entrada y el repartidor de tareas.

**Por qué:** trae integración nativa con Telegram, WhatsApp, Discord y Slack, más una app móvil de control. Es self-hosted. Ninguna otra herramienta evaluada resolvía la capa de mensajería sin tener que programarla.

**Descartados:**

| Herramienta | Motivo |
|---|---|
| **n8n** | Su nodo "AI Agent" no mantiene estado entre ejecuciones. Sirve para automatizaciones lineales, no para dirigir un agente que programa. Queda como opción futura para tareas periféricas (reportes, notificaciones). |
| **Hermes Agent** (NousResearch) | Bueno —memoria persistente, se auto-mejora escribiendo skills, 300+ modelos— pero redundante con Codex multi-modelo y sin capa de Telegram propia. |
| **OpenHands** (ex OpenDevin) | Abre PRs de forma nativa, pero exige su propio sandbox Docker. Más pesado y redundante con Codex. |

---

## ADR-004 — Codex CLI como único ejecutor

**Decisión:** todo el código lo escribe Codex CLI, cambiando de modelo por perfiles en `config.toml`.

**Por qué:**
- Ya está pagado dentro de la suscripción ChatGPT Plus/Pro del usuario.
- Soporta proveedores custom vía Responses API, así que el mismo binario apunta a DeepSeek, Qwen o GLM cambiando de perfil.
- Un solo ejecutor significa un solo comportamiento que aprender, un solo archivo de configuración y un solo sitio donde depurar.

**Plan B:** **Aider**, si manejar los perfiles de Codex resulta incómodo. Es nativo de git, soporta 100+ modelos cambiando solo `--model` y es muy liviano. A cambio no tiene sandbox, lo que obliga a ser más cuidadoso con los permisos.

---

## ADR-005 — Modelo caro para pensar, modelos baratos para escribir

**Decisión:** GPT-5.1 solo planifica y revisa. DeepSeek, Qwen y GLM escriben el código, los tests y la documentación.

**Por qué:** aproximadamente el 85 % de los tokens se consumen generando código, y ahí un modelo económico rinde bien. El 15 % restante —descomponer el problema y validar el resultado— es donde un error se propaga a todo lo demás, y ahí conviene el modelo bueno. Que además ya esté pagado hace la decisión trivial.

---

## ADR-006 — Ubuntu Server, y no Ubuntu Desktop

**Decisión:** **Ubuntu Server 24.04 LTS**.

Esta es la duda que más aparece al crear la VM, así que va con detalle.

| Criterio | Ubuntu **Server** | Ubuntu **Desktop** |
|---|---|---|
| RAM en reposo | ~400 MB – 1 GB | ~2,5 – 4 GB solo por el escritorio GNOME |
| Disco de instalación | ~5 GB | ~15 GB + actualizaciones gráficas |
| Interfaz | Solo terminal (SSH) | Escritorio gráfico |
| Superficie de ataque | Mínima: SSH y poco más | Mayor: navegador, gestor de sesión, servicios de escritorio |
| Actualizaciones | Pocas, casi siempre sin reinicio | Frecuentes, con paquetes gráficos pesados |
| Rendimiento en una VM sin GPU | Ideal | El escritorio se renderiza por CPU: desperdicio puro |

**Por qué Server gana en este caso concreto:**

1. **Nunca vas a mirar esta VM.** La operas desde el celular por Telegram, y cuando entras es por SSH vía Tailscale. Un escritorio gráfico al que nadie mira consume RAM las 24 horas para nada.
2. **Esos 2–3 GB de RAM importan.** El host tiene 21 GB libres, pero se le asignaron 6 GB a la VM: gastar la mitad en un escritorio deja sin margen a Docker y a Codex, que sí lo necesitan.
3. **Menos software, menos que asegurar.** Cada servicio de escritorio es superficie de ataque en una máquina que va a tener un token de GitHub y cuatro claves de API.
4. **Todo lo que se instala es CLI:** Docker, Tailscale, Codex CLI, git. Ninguno necesita entorno gráfico.

**Cuándo habría convenido Desktop:** si algún agente necesitara controlar un navegador con interfaz para pruebas end-to-end. No es el caso; y si llegara a serlo, se resuelve con un contenedor headless (Playwright, Selenium) sin instalar un escritorio completo.

**Versión:** 24.04 LTS, con soporte hasta 2029. Se prefiere sobre 26.04 salvo que esta última ya lleve varios meses publicada y con los repositorios de Docker y Tailscale confirmados para ella. En infraestructura conviene la LTS con rodaje, no la última.

> Si te equivocaste y ya instalaste Desktop: no hace falta reinstalar. Se puede quitar el escritorio con `sudo apt purge ubuntu-desktop gnome-shell && sudo apt autoremove`, pero queda más limpio rehacer la VM desde la ISO de Server.

---

## ADR-007 — Telegram por polling, sin abrir puertos

**Decisión:** el bot consulta a los servidores de Telegram (*polling*), en lugar de exponer un *webhook*.

**Por qué:** un webhook exigiría abrir un puerto en el router, tener IP pública o un túnel, y montar un certificado TLS. El polling logra lo mismo con conexiones **salientes**, que ningún firewall doméstico bloquea. Menos piezas, menos superficie expuesta.

**A cambio se acepta:** unos segundos de latencia adicional, irrelevantes para tareas que duran minutos.

---

## ADR-008 — Tailscale para el acceso remoto

**Decisión:** Tailscale instalado en la VM para llegar por SSH desde el celular.

**Por qué:** crea una red privada entre tus dispositivos sin abrir puertos ni publicar la IP de casa. La alternativa —redirigir el puerto 22 en el router— expone SSH a todo internet y a los escaneos automáticos que vienen con eso.

---

## ADR-009 — El merge lo aprueba una persona

**Decisión:** `main` protegida; ningún agente puede mergear. Siempre hay un PR y una aprobación humana.

**Por qué:** es el freno de mano del sistema. Un agente autónomo con permiso de escritura en `main` es exactamente la clase de cosa que funciona muy bien hasta el día en que no.

---

## Decisiones todavía abiertas

| Pregunta | Estado |
|---|---|
| ¿OpenClaw invoca Codex por CLI directo o hace falta un wrapper? | Resolver en la Fase 4 |
| ¿PAT o GitHub App? | El PAT alcanza para empezar; migrar si se suman más repos |
| ¿Dónde persiste la memoria de tareas de OpenClaw? | Verificar en la Fase 3 |
| ¿Los agentes comparten un clon del repo o cada uno el suyo? | Probable: uno por agente, para evitar pisarse. Confirmar en la Fase 5 |
