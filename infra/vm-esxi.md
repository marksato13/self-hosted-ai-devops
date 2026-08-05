# La VM en VMware ESXi

Specs, justificación y creación de la máquina virtual.

---

## Capacidad del host (medida)

| Recurso | Libre | Total | Uso |
|---|---|---|---|
| CPU | 8,5 GHz | 11,4 GHz | 25 % |
| RAM | 21,08 GB | 63,63 GB | 67 % |
| Disco | 258,81 GB | 825,75 GB | 69 % |

Hipervisor: **VMware ESXi 8.0 Update 3e**, licencia gratuita de Broadcom, sin vCenter. El único límite relevante de esa licencia es **8 vCPU por VM**, el doble de lo que se necesita.

---

## Specs de la VM

| Parámetro | Valor | Por qué |
|---|---|---|
| Nombre | `ai-devops` | |
| SO invitado | Ubuntu Linux (64 bits) | |
| Versión | **Ubuntu Server 24.04 LTS** | Headless — [ADR-006](../docs/decisiones.md#adr-006--ubuntu-server-y-no-ubuntu-desktop) |
| vCPU | 4 | Docker + Codex trabajan cómodos; quedan 4 de margen en la licencia |
| RAM | 6 GB | Server usa <1 GB en reposo; el resto es para el stack |
| Disco | 30 GB, aprovisionamiento fino | Ubuntu ~5 GB + Docker ~10 GB + workspace. Crece según uso |
| Red | Bridged (VM Network) | La VM toma IP de la LAN |
| Controladora | VMware Paravirtual (SCSI) | Mejor rendimiento con Linux |
| Adaptador de red | VMXNET3 | Ídem |

**Huella sobre el host:** 4 de 11,4 GHz de CPU, 6 de 21 GB de RAM libres y 30 de 258 GB de disco libre. Sobra margen.

---

## Por qué bridged y no NAT

Con **bridged**, la VM aparece como un equipo más de tu LAN, con su propia IP. Eso simplifica el SSH desde la red local y deja que Tailscale funcione sin capas extra.

No hace falta NAT ni redirección de puertos porque **todo el tráfico del sistema es saliente**: Telegram por polling, las APIs de modelos y GitHub. Nada entra desde internet.

---

## Crear la VM

Panel web del ESXi → *Máquinas virtuales* → *Crear/Registrar VM*:

1. **Crear una máquina virtual nueva**
2. Nombre `ai-devops`, compatibilidad ESXi 8.0 U2+, SO invitado *Linux → Ubuntu Linux (64 bits)*
3. Almacenamiento: el datastore con espacio libre
4. Personalizar hardware:
   - CPU **4**
   - Memoria **6144 MB**
   - Disco duro **30 GB**, *Aprovisionamiento fino*
   - Red **VM Network**, adaptador *VMXNET3*
   - Unidad de CD/DVD → *Archivo ISO del almacén de datos* → la ISO de Ubuntu Server
   - ✅ **Conectar al encender** en el CD/DVD ← si se olvida, la VM arranca sin instalador
5. Finalizar

📌 **Snapshot #1** con la VM creada y apagada, antes de instalar.

Instalación del sistema: [docs/instalacion.md — Fase 2](../docs/instalacion.md#fase-2--instalar-ubuntu-server-2404-lts).

---

## Snapshots

| # | Cuándo | Para volver a |
|---|---|---|
| 1 | VM creada, sin sistema | Reinstalar Ubuntu desde cero |
| 2 | Ubuntu + Docker + Tailscale | Rehacer solo el stack del proyecto |
| 3 | Stack completo funcionando | El último estado bueno conocido |

Los snapshots de ESXi crecen con el tiempo. Consolidá los viejos cuando ya no los necesites, o el datastore se llena sin que se note.

---

## Encendido automático

Para que la flota vuelva sola tras un corte de luz:

Panel del ESXi → *Administrar → Sistema → Inicio y apagado automáticos* → habilitar, y poner `ai-devops` en el arranque automático.

Con `restart: unless-stopped` en el compose, OpenClaw también vuelve solo al arrancar la VM.

---

## Si más adelante queda corta

| Síntoma | Ajuste |
|---|---|
| Se queda sin RAM (`free -h` con swap en uso constante) | Subir a 8 GB — hay margen en el host |
| Compilaciones o tests lentos | Subir a 6–8 vCPU (el tope de la licencia gratuita es 8) |
| Disco lleno (`df -h`) | `docker system prune -a` primero; ampliar el disco si persiste |

Ampliar CPU y RAM en ESXi requiere apagar la VM. El disco se puede ampliar en caliente, pero después hay que extender la partición desde Ubuntu.
