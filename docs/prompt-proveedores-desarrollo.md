# Prompt para configurar proveedores de desarrollo

Este prompt sirve para una extensión de Claude u otro agente con acceso al
repositorio y al panel de OmniRoute. No se agregan secretos al prompt.

```text
Trabaja en el repositorio actual self-hosted-ai-devops.

Objetivo:
Configurar proveedores de IA en OmniRoute de forma segura. Para desarrollo,
prioriza Codex por OAuth, Sonnet 5 cuando su proveedor esté conectado y
verificado, y rutas gratuitas/open source. Kimi y DeepSeek son rutas pagadas
opcionales: nunca las uses automáticamente ni ejecutes pruebas que consuman
saldo sin autorización explícita.

Orden de preferencia:
1. cx/gpt-5.6-sol para implementación y revisión exigente.
2. aug/sonnet5-high para arquitectura, código y revisión, solo después de
   confirmar proveedor, costo y funcionamiento.
3. aug/sonnet5-500k únicamente para contextos que realmente lo necesiten.
4. oc/big-pickle y oc/deepseek-v4-flash-free para trabajo gratuito.
5. DeepSeek y Kimi por nombre explícito, nunca como fallback gratuito.

Reglas de seguridad:
- Nunca muestres, copies en el chat, registres en logs ni hagas commit de
  contraseñas, tokens, cookies o API keys.
- No leas ni imprimas el contenido completo de .env.
- Conserva los secretos únicamente en el almacén cifrado de OmniRoute o en
  .env con permisos 600 cuando una integración local lo requiera.
- No agregues secretos a YAML, TOML, Markdown ni scripts.
- No ejecutes operaciones destructivas ni sobrescribas cambios sin revisarlos.
- No habilites recarga automática.
- No permitas que una ruta :free degrade a un proveedor de pago.
- Para OAuth, detente cuando la persona deba autorizar en el navegador y da el
  enlace y los pasos exactos.

Procedimiento:
1. Audita de solo lectura .gitignore, .env.example, compose, documentación,
   scripts, estado del contenedor y conexiones existentes.
2. Confirma OmniRoute 3.8.49 y su salud; no inventes rutas ni formatos.
3. Verifica Codex OAuth y OpenCode Free mediante una petición mínima.
4. Comprueba que las rutas gratuitas reporten costo cero cuando existan datos
   de costo.
5. Para Sonnet 5, distingue catálogo de disponibilidad real: exige conexión,
   prueba y revisión del plan antes de asignarlo a un agente.
6. Considera Kimi y DeepSeek de pago. Antes de cada prueba, informa el modelo,
   el posible costo y espera autorización explícita.
7. Usa auto/coding para calidad, auto/coding:free para volumen gratuito y
   auto/multimodal:free para tareas visuales gratuitas, comprobando que sus
   políticas no incluyan rutas pagadas.
8. Configura fallbacks, concurrencia y timeouts razonables sin modificar los
   límites de gasto del usuario.
9. Documenta instalación, inicio de sesión, proveedores, enlaces oficiales,
   variables, costos, pruebas, fallos conocidos y rotación de credenciales.
10. Ejecuta verificaciones reproducibles y muestra el diff antes de commit.
11. No hagas commit, push ni actives consumo de pago sin autorización.

Cuando necesites intervención humana, indica el botón, proporciona el enlace,
explica el resultado esperado y nunca pidas que peguen secretos en el chat.
```

## Observaciones operativas

- El catálogo es dinámico: volver a consultar `/v1/models` antes de fijar un ID.
- “Anunciado” no significa “probado”, “gratuito” ni “open source”.
- Si una clave se compartió en un chat, se considera comprometida: revocarla,
  generar otra e introducirla directamente en OmniRoute.
- El panel se abre solo por Tailscale Serve; nunca usar Tailscale Funnel.
