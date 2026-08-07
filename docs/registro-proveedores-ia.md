# Registro y claves de proveedores de IA

Guía para crear las cuentas y obtener las claves que consume LiteLLM en este
proyecto. Empezá con poco saldo y configurá límites de gasto antes de habilitar
los agentes.

> **Nunca pegues una clave en un chat, issue, commit o Pull Request.** Guardala
> directamente en el archivo `.env` privado de la VM. Si una clave se expone,
> revocala en la consola del proveedor y creá otra.

## Proveedores necesarios

| Proveedor | Uso previsto | Variable |
|---|---|---|
| OpenAI | Planificador y Revisor | `OPENAI_API_KEY` |
| DeepSeek | Backend | `DEEPSEEK_API_KEY` |
| Alibaba Model Studio / Qwen | Tests | `DASHSCOPE_API_KEY` |
| Zhipu BigModel / GLM | Documentación y visión | `ZHIPU_API_KEY` |
| Kimi / Moonshot | Respaldo opcional | `MOONSHOT_API_KEY` |

Kimi todavía es opcional: requiere agregar y probar su modelo en LiteLLM antes
de incorporarlo al flujo normal.

## 1. OpenAI

1. Entrá en [OpenAI Platform](https://platform.openai.com/) y registrate o
   iniciá sesión.
2. Configurá la facturación en
   [Billing](https://platform.openai.com/settings/organization/billing/overview).
3. Añadí inicialmente un saldo pequeño, por ejemplo entre USD 5 y USD 10.
4. Configurá un límite mensual bajo en la sección de límites.
5. Abrí [API Keys](https://platform.openai.com/api-keys).
6. Seleccioná **Create new secret key** y nombrala `self-hosted-ai-devops`.
7. Copiá la clave y guardala directamente en `.env`.

ChatGPT Plus o Pro y el uso de la API se facturan por separado. La referencia
oficial es el [inicio rápido de la API](https://platform.openai.com/docs/quickstart/make-your-first-api-request).

```dotenv
OPENAI_API_KEY=
```

## 2. DeepSeek

1. Abrí [DeepSeek Platform](https://platform.deepseek.com/) y seleccioná
   **Sign up**.
2. Confirmá el correo o teléfono si la plataforma lo solicita.
3. Entrá en [API Keys](https://platform.deepseek.com/api_keys).
4. Creá una clave llamada `self-hosted-ai-devops` y copiala.
5. Si no hay crédito gratuito, añadí un importe pequeño en
   [Top Up](https://platform.deepseek.com/top_up).
6. Revisá los modelos y precios vigentes en la
   [documentación oficial](https://api-docs.deepseek.com/).

```dotenv
DEEPSEEK_API_KEY=
```

Los nombres de modelos cambian. Hay que comprobar el modelo vigente con una
llamada de prueba antes de activar el agente Backend.

## 3. Qwen — Alibaba Cloud Model Studio

Este proyecto usa el endpoint internacional de **Singapur**. La clave tiene que
crearse en esa misma región; una clave de Beijing no es intercambiable.

1. Registrate en
   [Alibaba Cloud](https://account.alibabacloud.com/register/intl_register.htm).
2. Entrá en [Model Studio](https://modelstudio.console.alibabacloud.com/).
3. En la esquina superior derecha seleccioná **Singapore**.
4. Activá Model Studio y aceptá sus condiciones si aparece el asistente.
5. Abrí **API Key Management** y creá una clave normal de pago por uso.
6. Usá el workspace predeterminado y el nombre `self-hosted-ai-devops`.
7. Copiá la clave inmediatamente: las claves nuevas pueden mostrarse completas
   una sola vez.
8. No uses **Token Plan** ni **Coding Plan** para LiteLLM; esos planes están
   destinados a herramientas de programación interactivas, no a servicios
   backend.

Consultá las instrucciones oficiales para
[obtener una API key](https://help.aliyun.com/en/model-studio/get-api-key) y los
[endpoints por región](https://help.aliyun.com/en/model-studio/base-url).

```dotenv
DASHSCOPE_API_KEY=
```

## 4. GLM — Zhipu BigModel

1. Abrí [Zhipu BigModel](https://open.bigmodel.cn/) y registrate o iniciá
   sesión.
2. Completá la verificación que solicite el proveedor.
3. Entrá en [API Keys](https://open.bigmodel.cn/usercenter/apikeys).
4. Creá una clave para `self-hosted-ai-devops` y copiala.
5. Activá saldo o facturación únicamente si el crédito gratuito no alcanza.
6. No compres un **Coding Plan** para este servicio: LiteLLM necesita una clave
   normal de la plataforma.

La referencia oficial es la
[guía de inicio de BigModel](https://docs.bigmodel.cn/cn/guide/start/quick-start).

```dotenv
ZHIPU_API_KEY=
```

Hay que probar los modelos GLM de texto y visión vigentes antes de habilitar los
perfiles `docs` y `designer`.

## 5. Kimi — Moonshot AI (opcional)

1. Abrí [Kimi API Platform](https://platform.kimi.com/) y registrate o iniciá
   sesión.
2. Entrá en [API Keys](https://platform.kimi.com/console/api-keys).
3. Creá una clave llamada `self-hosted-ai-devops` y copiala.
4. Si la plataforma exige saldo, cargá inicialmente una cantidad pequeña.
5. No contrates un plan grande hasta probar una llamada mediante LiteLLM.

La [guía oficial de Kimi](https://platform.kimi.com/docs/overview) documenta su
API compatible con OpenAI y la variable `MOONSHOT_API_KEY`.

```dotenv
MOONSHOT_API_KEY=
```

## Guardar las claves en la VM

No envíes las claves a otra persona ni las pegues en un chat. Abrí una terminal
en la VM y ejecutá:

```bash
cd /home/m4rk/self-hosted-ai-devops
nano .env
```

Completá las líneas correspondientes:

```dotenv
OPENAI_API_KEY=
DEEPSEEK_API_KEY=
DASHSCOPE_API_KEY=
ZHIPU_API_KEY=
MOONSHOT_API_KEY=
```

En `nano`, guardá con `Ctrl+O`, confirmá con `Enter` y salí con `Ctrl+X`.
Comprobá que solo tu usuario pueda leer el archivo:

```bash
chmod 600 .env
stat -c '%a %n' .env
```

El resultado esperado es `600 .env`. No uses `cat .env`, no captures la
pantalla y no copies su contenido a una conversación.

## Validación posterior

Una vez guardadas las claves, se debe:

1. Comprobar solamente que cada variable tenga valor, sin imprimirlo.
2. Confirmar los nombres actuales de los modelos en cada consola.
3. Probar cada proveedor individualmente con una petición mínima.
4. Configurar y probar Kimi como fallback opcional.
5. Reiniciar LiteLLM y ejecutar la verificación del proyecto.
6. Revisar consumo y límites en las cinco consolas.

Si una prueba devuelve `401`, revisar primero que la clave y el endpoint sean
de la misma región. Si devuelve un error de saldo, no aumentar el límite hasta
confirmar que el modelo configurado es el correcto.
