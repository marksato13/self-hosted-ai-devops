import { linkSync, mkdirSync, readFileSync, renameSync, rmSync, writeFileSync } from "node:fs";
import { join } from "node:path";

const number = /^[1-9][0-9]{0,9}$/;
const nonce = /^[a-f0-9]{32}$/;
const queue = process.env.AI_QUEUE_DIR || "/queue";
const state = process.env.TELEGRAM_STATE_DIR || "/state";
const tokenPath = process.env.TELEGRAM_BOT_TOKEN_FILE || "/run/secrets/telegram_bot_token";
const token = readFileSync(tokenPath, "utf8").trim();
const allowed = new Set((process.env.TELEGRAM_ALLOWED_CHAT_IDS || "").split(",").filter(Boolean));
if (!token || allowed.size === 0) throw new Error("Faltan token de Telegram o allowlist.");

const comandos = new Map([
  ["aprobar", (v) => number.test(v) ? ["aprobar", v] : null], ["a", (v) => number.test(v) ? ["aprobar", v] : null],
  ["rechazar", (v) => number.test(v) ? ["rechazar", v] : null], ["confirmar", (v) => nonce.test(v) ? ["confirmar", v] : null],
  ["c", (v) => nonce.test(v) ? ["confirmar", v] : null], ["aprobar_todo", (v) => !v ? ["aprobar-todo", ""] : null],
  ["todo", (v) => !v ? ["aprobar-todo", ""] : null], ["estado", (v) => !v ? ["estado", ""] : null],
  ["agentes", (v) => !v ? ["agentes", ""] : null], ["trabajo", (v) => !v ? ["agentes", ""] : null],
  ["salud", (v) => !v ? ["salud", ""] : null], ["sig", (v) => !v ? ["siguiente", ""] : null],
  ["pausa", (v) => !v ? ["detener", ""] : null], ["seguir", (v) => !v ? ["reanudar", ""] : null],
  ["i", (v) => number.test(v) ? ["issue", v] : null], ["error", (v) => !v || number.test(v) ? ["errores", v] : null],
  ["ayuda", (v) => !v ? ["ayuda", ""] : null],
]);

function parsear(texto) {
  const [raw = "", valor = "", extra] = texto.trim().split(/\s+/);
  const nombre = raw.replace(/^\//, "").split("@")[0].toLowerCase();
  if (extra !== undefined || !comandos.has(nombre)) return null;
  return comandos.get(nombre)(valor);
}
function guardar(accion, valor, actor) {
  const control = join(queue, "control"); mkdirSync(control, { recursive: true, mode: 0o700 });
  const id = `${new Date().toISOString().replace(/[-:.]/g, "")}-${process.pid}-${crypto.randomUUID()}`;
  const temporal = join(control, `.${id}.tmp`); const destino = join(control, `${id}.pending`);
  writeFileSync(temporal, `${JSON.stringify({ version: 1, id, accion, valor, actor: String(actor), creado: new Date().toISOString() })}\n`, { mode: 0o600, flag: "wx" });
  try { linkSync(temporal, destino); } finally { rmSync(temporal, { force: true }); }
}
async function telegram(method, body) {
  const response = await fetch(`https://api.telegram.org/bot${token}/${method}`, { method: "POST", headers: { "content-type": "application/json" }, body: JSON.stringify(body), signal: AbortSignal.timeout(40_000) });
  const json = await response.json(); if (!response.ok || !json.ok) throw new Error(`Telegram ${response.status}`); return json.result;
}
function offsetLeer() { try { return Number.parseInt(readFileSync(join(state, "offset"), "utf8"), 10) || 0; } catch { return 0; } }
function offsetGuardar(offset) { mkdirSync(state, { recursive: true, mode: 0o700 }); const temporal = join(state, ".offset.tmp"); writeFileSync(temporal, `${offset}\n`, { mode: 0o600 }); renameSync(temporal, join(state, "offset")); }
function esperar(ms) { return new Promise((resolve) => setTimeout(resolve, ms)); }
let offset = offsetLeer();
for (;;) {
  try {
    const updates = await telegram("getUpdates", { offset, timeout: 30, allowed_updates: ["message"] });
    for (const update of updates) {
      offset = update.update_id + 1; offsetGuardar(offset); const message = update.message;
      if (!message?.text || !allowed.has(String(message.chat?.id))) continue;
      const orden = parsear(message.text);
      if (!orden) { await telegram("sendMessage", { chat_id: message.chat.id, text: "Comando inválido. Usa /ayuda." }); continue; }
      guardar(orden[0], orden[1], message.chat.id);
      await telegram("sendMessage", { chat_id: message.chat.id, text: `Solicitud ${orden[0]} aceptada. Nexo enviará el resultado por Telegram.` });
    }
  } catch (error) { console.error(`Telegram control: ${error.message}`); await esperar(3_000); }
}
