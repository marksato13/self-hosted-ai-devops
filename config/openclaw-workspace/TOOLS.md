# Herramientas

Política deny-by-default. El chat no dispone de navegador ni escritura directa
sobre repositorios. La herramienta de ejecución está detrás de una allowlist
que solo admite `/usr/local/bin/control-flota`; cualquier otro binario falla.

`control-flota` admite únicamente acciones cerradas y valida de nuevo el
`chat_id` recibido en `OPENCLAW_CHANNEL_CONTEXT`. Escribe sobres JSON atómicos
en la cola local. GitHub, Codex, Docker y los secretos permanecen en el host.

El merge necesita dos mensajes humanos: `aprobar PR` genera un código de un
solo uso y `confirmar CODIGO` autoriza el SHA exacto durante unos minutos.
`aprobar-todo` hace lo mismo para el lote actual de PR `integra/issue-*`
abiertos y verdes. La confirmación queda ligada al actor, a la lista y al SHA
de cada PR; se detiene ante el primer fallo y nunca usa `--admin` ni bypass.
