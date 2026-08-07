# Conectar modelos sin costo adicional

Esta instalación ya no requiere claves comerciales. No compres créditos de
OpenAI API, DeepSeek, Alibaba, Zhipu ni Kimi.

> No envíes contraseñas, cookies, códigos OAuth ni claves por chat. Toda
> autenticación se completa directamente en el dashboard local de OmniRoute.

## 1. Habilitar el panel privado

OmniRoute escucha solo en `127.0.0.1:20128`. Para verlo desde el celular o una
PC de tu tailnet:

```bash
tailscale serve --bg --yes 20128
tailscale serve status
```

Tailscale mostrará una URL HTTPS privada. Si pide activar Serve, abrí el enlace
de autorización y aprobalo. No uses Funnel: Funnel publicaría el panel en
Internet.

## 2. Entrar al dashboard

En la VM, obtené la contraseña sin copiarla a una conversación:

```bash
cd /home/m4rk/self-hosted-ai-devops
grep '^OMNIROUTE_INITIAL_PASSWORD=' .env
```

Usala para iniciar sesión en la URL privada y guardala en tu gestor de
contraseñas. No captures ni compartas la pantalla que la contiene.

## 3. Conectar Codex con ChatGPT Plus

1. En OmniRoute, abrir **Providers**.
2. Elegir **Codex** y **Connect with OAuth**.
3. Iniciar sesión en la cuenta que ya tiene ChatGPT Plus.
4. Aprobar el acceso y volver al dashboard.
5. Confirmar que la conexión aparece saludable y que muestra cuota.

Esto usa los límites de la suscripción existente. ChatGPT Plus no incluye la
API comercial de OpenAI, por lo que `OPENAI_API_KEY` no se utiliza.

## 4. Confirmar OpenCode Free

1. En **Providers**, buscar **OpenCode Free**.
2. Activarlo si no aparece ya como disponible.
3. Probar uno de sus modelos desde el Playground.
4. No importar cookies ni sesiones web.

OpenCode Free funciona sin una clave en la instalación verificada. Su cuota y
catálogo pueden cambiar.

## 5. Proveedores gratuitos adicionales

OmniRoute mantiene un
[catálogo de capas gratuitas](https://github.com/diegosouzapw/OmniRoute/blob/main/docs/reference/FREE_TIERS.md).
Antes de conectar uno:

1. Confirmar que la cuota es recurrente, no solo crédito de bienvenida.
2. Revisar la columna de términos de servicio.
3. Usar solamente una cuenta propia y para uso personal.
4. No conectar proveedores marcados `avoid`.
5. No añadir tarjeta, depósito ni recarga automática.
6. Probar el modelo desde el dashboard y comprobar costo cero.

Buenas opciones para evaluar son las APIs oficiales con capa gratuita de
Mistral, Groq, Cerebras y Gemini Flash, pero sus requisitos y cuotas cambian.
No son necesarias para arrancar.

## 6. Clave local de Codex

La clave que usa Codex es interna de OmniRoute, no pertenece a un proveedor:

```bash
./scripts/crear-clave-omniroute.sh
./scripts/instalar-config-codex.sh
```

Se guarda como `OMNIROUTE_API_KEY` en `.env` con permisos `600` y nunca se
imprime.

## 7. Comprobación

```bash
./scripts/verificar.sh 5
set -a; source .env; set +a
codex --profile tester "responde solamente OK"
```

Los perfiles de volumen usan `auto/coding:free`; el diseñador usa
`auto/multimodal:free`. Consultá [OmniRoute](omniroute.md) para la arquitectura,
seguridad y recuperación.
