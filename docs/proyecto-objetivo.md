# Proyecto objetivo: NinjaSec

La flota trabaja sobre un repositorio distinto al de infraestructura:

| Campo | Valor |
|---|---|
| GitHub | `marksato13/ninjasec-platform` (privado) |
| Clon local | `/home/m4rk/workspace/ninjasec-platform` |
| Rama principal | `main` |
| Aplicación | `PY-MK/` |
| Requisitos | `DOCUMENTOS/PLATAFORMA/PLANIFICACION/` |
| Evidencia | `DOCUMENTOS/PLATAFORMA/IMPLEMENTACION/` |
| Prioridad | `DOCUMENTOS/PLATAFORMA/ROADMAP.md` |

## Línea base del 7 de agosto de 2026

- Backend: 63 pruebas correctas.
- Frontend: build correcto, 41 rutas; conserva warnings de lint conocidos.
- Dependencias frontend: 5 vulnerabilidades altas y ninguna crítica según
  `npm audit`; no se aplican upgrades automáticos sin revisar compatibilidad.
- Gitleaks: árbol e historial sin hallazgos pendientes después de retirar un
  ejemplo inseguro y registrar su fingerprint histórico.
- GitHub Actions: jobs de backend, frontend y secretos verificados.
- GitHub no ofrece branch protection para este repositorio privado con el plan
  actual. La compensación es no trabajar en `main`, exigir PR y verificar CI
  inmediatamente antes de cada merge autorizado.

## Orden de trabajo

1. Fusionar el PR de gobernanza y CI tras autorización humana.
2. Resolver G-01/G-02: migración base Alembic antes del deploy self-hosted.
3. Ejecutar 23-P1: interfaz de topología con React Flow, según el roadmap.
4. Completar 23-P2: editor de conexiones.
5. Continuar por las tandas documentadas en NinjaSec.

La flota nunca toma `tash/` como fuente de verdad y respeta completamente
`AGENTS.md` y `PY-MK/CLAUDE.md` del repositorio objetivo.

## Primer Pull Request

El PR [marksato13/ninjasec-platform#1](https://github.com/marksato13/ninjasec-platform/pull/1)
agrega gobernanza para agentes, CI reproducible y escaneo de secretos. Todos
sus checks están verdes. El merge sigue pendiente de autorización humana.
