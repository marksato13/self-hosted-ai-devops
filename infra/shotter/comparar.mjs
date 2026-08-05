// ============================================================
//  comparar.mjs — diferencia visual entre dos conjuntos
// ============================================================
//    node comparar.mjs --antes /salida/base --despues /salida/rama --umbral 0.1
//
//  Deja en <despues>/diff/ una imagen por par, con los píxeles
//  cambiados pintados en rojo, y escribe diferencias.json.
//
//  Salida:
//    0 — ninguna diferencia supera el umbral (sin regresión visual)
//    1 — al menos una lo supera (hay que mirar)
//    2 — error de entrada (faltan archivos)
//
//  El agente lee el código de salida, no el texto.
// ============================================================

import pixelmatch from 'pixelmatch';
import { PNG } from 'pngjs';
import { readdir, readFile, writeFile, mkdir } from 'node:fs/promises';
import path from 'node:path';

const args = Object.fromEntries(
  process.argv.slice(2).flatMap((a, i, arr) =>
    a.startsWith('--') ? [[a.slice(2), arr[i + 1]?.startsWith('--') ? true : arr[i + 1]]] : []
  )
);

const ANTES   = args.antes   ?? '/salida/base';
const DESPUES = args.despues ?? '/salida/rama';
const UMBRAL  = parseFloat(args.umbral ?? '0.1');   // % de píxeles cambiados
const DIFFDIR = path.join(DESPUES, 'diff');

// Dos capturas de la misma página rara vez miden lo mismo: si el
// contenido creció, la altura cambió. Rellenamos ambas al tamaño
// mayor para poder compararlas píxel a píxel.
function encuadrar(png, ancho, alto) {
  if (png.width === ancho && png.height === alto) return png;
  const lienzo = new PNG({ width: ancho, height: alto });
  lienzo.data.fill(255);                       // fondo blanco
  PNG.bitblt(png, lienzo, 0, 0, png.width, png.height, 0, 0);
  return lienzo;
}

let archivos;
try {
  archivos = (await readdir(ANTES)).filter(f => f.endsWith('.png'));
} catch {
  console.error(`No se puede leer ${ANTES}. ¿Se corrió capturar.mjs?`);
  process.exit(2);
}
if (archivos.length === 0) {
  console.error(`No hay PNG en ${ANTES}.`);
  process.exit(2);
}

await mkdir(DIFFDIR, { recursive: true });

const resultados = [];
let superan = 0;

for (const nombre of archivos) {
  let a, b;
  try {
    a = PNG.sync.read(await readFile(path.join(ANTES, nombre)));
    b = PNG.sync.read(await readFile(path.join(DESPUES, nombre)));
  } catch {
    resultados.push({ archivo: nombre, estado: 'falta-par', porcentaje: null });
    console.log(`  ? ${nombre.padEnd(38)} sin par en «después»`);
    continue;
  }

  const ancho = Math.max(a.width, b.width);
  const alto  = Math.max(a.height, b.height);
  const A = encuadrar(a, ancho, alto);
  const B = encuadrar(b, ancho, alto);
  const salida = new PNG({ width: ancho, height: alto });

  // threshold 0.15 tolera el antialiasing del renderizado, que
  // cambia entre corridas sin que nadie haya tocado el diseño.
  const distintos = pixelmatch(A.data, B.data, salida.data, ancho, alto, {
    threshold: 0.15,
    includeAA: false,
    diffColor: [255, 0, 0],
    alpha: 0.25,
  });

  const porcentaje = +((distintos / (ancho * alto)) * 100).toFixed(3);
  const supera = porcentaje > UMBRAL;
  if (supera) superan++;

  await writeFile(path.join(DIFFDIR, nombre), PNG.sync.write(salida));
  resultados.push({
    archivo: nombre,
    porcentaje,
    pixeles: distintos,
    supera,
    dimensiones: { antes: [a.width, a.height], despues: [b.width, b.height] },
  });

  console.log(`  ${supera ? '!' : '·'} ${nombre.padEnd(38)} ${String(porcentaje).padStart(7)} %`);
}

await writeFile(
  path.join(DESPUES, 'diferencias.json'),
  JSON.stringify({ antes: ANTES, despues: DESPUES, umbral: UMBRAL, resultados }, null, 2)
);

const peor = resultados.reduce((m, r) => Math.max(m, r.porcentaje ?? 0), 0);
console.log(`\n  Mayor diferencia: ${peor} %  ·  umbral: ${UMBRAL} %  ·  imágenes por encima: ${superan}`);
console.log(`  → ${DIFFDIR}`);

process.exit(superan > 0 ? 1 : 0);
