# ============================================================
#  shotter — el ojo de la flota
# ============================================================
#  Chromium headless dentro de un contenedor. Es lo que permite
#  que una VM Ubuntu Server SIN escritorio tome capturas de
#  pantalla: el navegador renderiza en memoria, no en una pantalla.
#
#  La imagen de Playwright ya trae Chromium, Firefox y WebKit
#  con todas sus dependencias de sistema resueltas. Instalar
#  Chromium a mano en Ubuntu Server es una tarde de librerías
#  faltantes (libnss3, libatk, libgbm…); esto lo evita.
#
#  Ver docs/bucle-visual.md
# ============================================================

# ⚠️ Esta versión debe coincidir con la de package.json, o el
#    navegador de la imagen y la librería no se entienden.
ARG PW_VERSION=1.56.0
FROM mcr.microsoft.com/playwright:v${PW_VERSION}-noble

WORKDIR /app

# Las dependencias primero: cambian mucho menos que los scripts,
# así el rebuild tras editar un .mjs no reinstala nada.
COPY package.json ./
RUN npm install --omit=dev --no-audit --no-fund

COPY *.mjs ./

# Sin root: si una página maliciosa escapara del sandbox de
# Chromium, no cae en un contenedor con privilegios.
USER pwuser

ENTRYPOINT ["node"]
CMD ["capturar.mjs", "--help"]
