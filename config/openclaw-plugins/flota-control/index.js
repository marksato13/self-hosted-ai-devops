import { randomUUID } from "node:crypto";
import { mkdirSync, writeFileSync, linkSync, unlinkSync } from "node:fs";
import { join } from "node:path";
import { definePluginEntry } from "openclaw/plugin-sdk/plugin-entry";

const NUMERO = /^[1-9][0-9]{0,9}$/;
const NONCE = /^[a-f0-9]{32}$/;

function autorizado(ctx) {
  const ids = new Set((process.env.TELEGRAM_ALLOWED_CHAT_IDS || "").split(",").filter(Boolean));
  return ctx.channel === "telegram" && ctx.isAuthorizedSender === true && ids.has(String(ctx.senderId));
}

function guardar(accion, valor, actor) {
  const cola = join(process.env.AI_QUEUE_DIR || "/queue", "control");
  mkdirSync(cola, { recursive: true, mode: 0o700 });
  const id = `${new Date().toISOString().replace(/[-:.]/g, "")}-${process.pid}-${randomUUID()}`;
  const temporal = join(cola, `.${id}.tmp`);
  const destino = join(cola, `${id}.pending`);
  const sobre = { version: 1, id, accion, valor, actor: String(actor), creado: new Date().toISOString() };
  writeFileSync(temporal, `${JSON.stringify(sobre)}\n`, { mode: 0o600, flag: "wx" });
  try { linkSync(temporal, destino); } finally { unlinkSync(temporal); }
}

function comando(api, name, description, parsear) {
  api.registerCommand({
    name, description, acceptsArgs: true, requireAuth: true,
    handler: async (ctx) => {
      if (!autorizado(ctx)) return { text: "Solicitud rechazada: remitente no autorizado." };
      const resultado = parsear((ctx.args || "").trim());
      if (resultado.error) return { text: resultado.error };
      guardar(resultado.accion, resultado.valor || "", ctx.senderId);
      return { text: `Solicitud ${resultado.accion} aceptada. Nexo enviará el resultado por Telegram.` };
    },
  });
}

export default definePluginEntry({
 id: "flota-control",
 name: "Control determinista de la flota",
 description: "Convierte comandos Telegram autorizados en solicitudes de control cerradas.",
 register(api) {
  comando(api, "aprobar", "Preparar la aprobación de un PR", (v) =>
    NUMERO.test(v) ? { accion: "aprobar", valor: v } : { error: "Uso: /aprobar NUMERO_PR" });
  comando(api, "rechazar", "Rechazar un PR", (v) =>
    NUMERO.test(v) ? { accion: "rechazar", valor: v } : { error: "Uso: /rechazar NUMERO_PR" });
  comando(api, "confirmar", "Confirmar una aprobación pendiente", (v) =>
    NONCE.test(v) ? { accion: "confirmar", valor: v } : { error: "Uso: /confirmar CODIGO" });
  comando(api, "aprobar_todo", "Preparar la aprobación del lote actual", (v) =>
    v ? { error: "Uso: /aprobar_todo" } : { accion: "aprobar-todo" });
  // Atajos del menú: conservan la misma validación y confirmación.
  comando(api, "a", "Atajo: aprobar un PR", (v) =>
    NUMERO.test(v) ? { accion: "aprobar", valor: v } : { error: "Uso: /a NUMERO_PR" });
  comando(api, "c", "Atajo: confirmar con código", (v) =>
    NONCE.test(v) ? { accion: "confirmar", valor: v } : { error: "Uso: /c CODIGO" });
  comando(api, "todo", "Atajo: aprobar el lote actual", (v) =>
    v ? { error: "Uso: /todo" } : { accion: "aprobar-todo" });
  comando(api, "estado", "Ver estado de la flota", (v) =>
    v ? { error: "Uso: /estado" } : { accion: "estado" });
  comando(api, "agentes", "Ver qué agentes trabajan y su fase", (v) =>
    v ? { error: "Uso: /agentes" } : { accion: "agentes" });
  comando(api, "trabajo", "Atajo: ver agentes y progreso", (v) =>
    v ? { error: "Uso: /trabajo" } : { accion: "agentes" });
  comando(api, "salud", "Ver salud del entorno y dependencias", (v) =>
    v ? { error: "Uso: /salud" } : { accion: "salud" });
  comando(api, "sig", "Procesar el siguiente issue", (v) =>
    v ? { error: "Uso: /sig" } : { accion: "siguiente" });
  comando(api, "pausa", "Pausar admisión de tareas", (v) =>
    v ? { error: "Uso: /pausa" } : { accion: "detener" });
  comando(api, "seguir", "Reanudar la flota", (v) =>
    v ? { error: "Uso: /seguir" } : { accion: "reanudar" });
  comando(api, "i", "Procesar un issue concreto", (v) =>
    NUMERO.test(v) ? { accion: "issue", valor: v } : { error: "Uso: /i NUMERO_ISSUE" });
  comando(api, "error", "Ver errores recientes", (v) =>
    (!v || NUMERO.test(v)) ? { accion: "errores", valor: v } : { error: "Uso: /error [NUMERO_ISSUE]" });
  comando(api, "flota", "Controlar o consultar la flota", (v) => {
    const [accion = "ayuda", valor = "", extra] = v.split(/\s+/);
    if (["estado", "siguiente", "detener", "reanudar", "ayuda"].includes(accion) && !valor)
      return { accion };
    if (accion === "issue" && NUMERO.test(valor) && !extra) return { accion, valor };
    if (accion === "errores" && (!valor || NUMERO.test(valor)) && !extra) return { accion, valor };
    return { error: "Uso: /flota estado|siguiente|issue N|detener|reanudar|errores [N]|ayuda" };
  });
 },
});
