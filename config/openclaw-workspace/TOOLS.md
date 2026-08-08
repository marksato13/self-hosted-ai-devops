# Herramientas

Política deny-by-default. El modelo no dispone de `exec`, navegador ni escritura
directa sobre repositorios. Los comandos slash nativos del plugin
`flota-control` validan canal, autorización, `chat_id` y gramática, y escriben
únicamente sobres JSON atómicos en la cola local.

GitHub, Codex, Docker y los secretos permanecen en el host.

El merge necesita dos mensajes humanos: `aprobar PR` genera un código de un
solo uso y `confirmar CODIGO` autoriza el SHA exacto durante unos minutos.
`aprobar-todo` hace lo mismo para el lote actual de PR `integra/issue-*`
abiertos y verdes. La confirmación queda ligada al actor, a la lista y al SHA
de cada PR; se detiene ante el primer fallo y nunca usa `--admin` ni bypass.
