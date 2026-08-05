// ============================================================
//  capturar.mjs — toma las capturas y audita accesibilidad
// ============================================================
//  Corre dentro del contenedor `shotter`, contra el `stage`.
//
//    node capturar.mjs --etiqueta antes
//    node capturar.mjs --etiqueta despues --config /config/capturas.json
//
//  Deja en /salida/<etiqueta>/:
//    <ruta>__<viewport>.png     una por combinación
//    accesibilidad.json         hallazgos objetivos de axe-core
//    resumen.json               índice de lo capturado
//
//  Salida: 0 si capturó todo, 1 si alguna ruta falló.
// ============================================================

import { chromium } from 'playwright';
import AxeBuilder from '@axe-core/playwright';
import { mkdir, writeFile } from 'node:fs/promises';
import path from 'node:path';

const args = Object.fromEntries(
  process.argv.slice(2).flatMap((a, i, arr) =>
    a.startsWith('--') ? [[a.slice(2), arr[i + 1]?.startsWith('--') ? true : arr[i + 1]]] : []
  )
);

if (args.help) {
  console.log('uso: node capturar.mjs --etiqueta <nombre> [--config ruta] [--base url]');
  process.exit(0);
}

const ETIQUETA = args.etiqueta ?? 'sin-etiqueta';
const CONFIG   = args.config  ?? '/config/capturas.json';
const SALIDA   = path.join(args.salida ?? '/salida', ETIQUETA);

const cfg = JSON.parse(await import('node:fs').then(fs => fs.promises.readFile(CONFIG, 'utf8')));
const BASE = args.base ?? cfg.base ?? 'http://stage';

const viewports = cfg.viewports ?? [
  { nombre: 'movil',     ancho: 390,  alto: 844  },
  { nombre: 'tablet',    ancho: 834,  alto: 1112 },
  { nombre: 'escritorio', ancho: 1440, alto: 900 },
];

await mkdir(SALIDA, { recursive: true });

// Chromium headless. --no-sandbox es necesario dentro de Docker;
// el aislamiento real lo da el contenedor, no el sandbox del navegador.
const navegador = await chromium.launch({ args: ['--no-sandbox', '--disable-dev-shm-usage'] });

const capturas = [];
const hallazgos = [];
let fallos = 0;

for (const vp of viewports) {
  const contexto = await navegador.newContext({
    viewport: { width: vp.ancho, height: vp.alto },
    deviceScaleFactor: 1,
    // Sin animaciones ni cursor parpadeante: si no, dos capturas
    // idénticas dan diferencias y el comparador reporta ruido.
    reducedMotion: 'reduce',
    colorScheme: cfg.tema ?? 'light',
  });
  const pagina = await contexto.newPage();

  for (const r of cfg.rutas ?? [{ nombre: 'inicio', ruta: '/' }]) {
    const url = new URL(r.ruta, BASE).toString();
    const archivo = path.join(SALIDA, `${r.nombre}__${vp.nombre}.png`);

    try {
      await pagina.goto(url, { waitUntil: cfg.esperar ?? 'networkidle', timeout: 30_000 });

      // Congelar animaciones CSS: misma razón que reducedMotion.
      await pagina.addStyleTag({
        content: `*,*::before,*::after{animation:none!important;transition:none!important;
                  caret-color:transparent!important;scroll-behavior:auto!important}`,
      });
      if (r.esperarSelector) await pagina.waitForSelector(r.esperarSelector, { timeout: 15_000 });
      await pagina.waitForTimeout(cfg.reposoMs ?? 400);

      await pagina.screenshot({ path: archivo, fullPage: r.paginaCompleta ?? true });
      capturas.push({ ruta: r.nombre, viewport: vp.nombre, archivo: path.basename(archivo), url });
      console.log(`  ✓ ${r.nombre} @ ${vp.nombre}`);

      // Accesibilidad: una sola vez por ruta, en escritorio.
      // Esto NO es cuestión de gusto — son reglas medibles
      // (contraste, etiquetas, foco). Ver docs/bucle-visual.md
      if ((cfg.accesibilidad ?? true) && vp === viewports[viewports.length - 1]) {
        const { violations } = await new AxeBuilder({ page: pagina })
          .withTags(['wcag2a', 'wcag2aa'])
          .analyze();
        for (const v of violations) {
          hallazgos.push({
            ruta: r.nombre,
            regla: v.id,
            impacto: v.impact,
            descripcion: v.description,
            elementos: v.nodes.slice(0, 5).map(n => n.target.join(' ')),
          });
        }
      }
    } catch (e) {
      fallos++;
      console.error(`  ✗ ${r.nombre} @ ${vp.nombre}: ${e.message.split('\n')[0]}`);
    }
  }

  await contexto.close();
}

await navegador.close();

await writeFile(path.join(SALIDA, 'accesibilidad.json'), JSON.stringify(hallazgos, null, 2));
await writeFile(
  path.join(SALIDA, 'resumen.json'),
  JSON.stringify({ etiqueta: ETIQUETA, base: BASE, fecha: new Date().toISOString(), capturas, fallos }, null, 2)
);

console.log(`\n  ${capturas.length} capturas · ${hallazgos.length} hallazgos de accesibilidad · ${fallos} fallos`);
console.log(`  → ${SALIDA}`);

process.exit(fallos > 0 ? 1 : 0);
