# AGENTS.md

Instrucciones para los agentes de IA que trabajan en este repositorio.
Codex CLI, Claude Code, Cursor y Aider leen este archivo automáticamente.

## Qué es este proyecto

Flota de agentes de IA autohospedada en una VM Ubuntu Server sobre VMware ESXi,
comandada por Telegram. Hoy es **documentación de infraestructura**, no una
aplicación: no hay código que compilar ni tests que correr todavía.

## Estructura

```
docs/     documentación (la mayor parte del repo)
infra/    docker-compose de OpenClaw y LiteLLM, specs de la VM
config/   plantillas de configuración (solo archivos .example)
scripts/  utilidades de worktrees para el trabajo en paralelo
```

## Reglas que no se negocian

1. **Nunca commitear secretos.** Ni claves, ni tokens, ni el `.env`.
   Los archivos de configuración se versionan solo como `.example`, con
   valores vacíos. Gitleaks corre en pre-commit y va a bloquear el commit.
2. **Nunca hacer push a `main`.** Está protegida. Se trabaja en una rama
   y se abre un Pull Request.
3. **Nunca mergear.** El merge lo aprueba una persona, siempre.
4. **Un agente toca solo los archivos de su subtarea.** Los otros agentes
   están trabajando en paralelo en el mismo repo.

## Convenciones

**Idioma:** todo en español — documentación, comentarios y mensajes de commit.

**Ramas:** `<tipo>/issue-<n>[-<agente>]`

```
feat/issue-12-backend
test/issue-12
docs/issue-12
integra/issue-12      ← solo la crea el Revisor
```

**Commits:** imperativo, una línea, en español.

```
Agrega la fase de LiteLLM a la guía de instalación
```

**Documentación:** los diagramas van en Mermaid dentro del `.md`, para que
GitHub los renderice. Sin imágenes externas.

**Enlaces entre documentos:** relativos (`../docs/modelos.md`), nunca URLs
absolutas de github.com.

## Cómo verificar un cambio

No hay suite de tests. Antes de abrir un PR:

```bash
gitleaks protect --staged --no-banner    # no se escapó ningún secreto
docker compose -f infra/docker-compose.yml config    # el compose es válido
```

Y a ojo: que los enlaces relativos entre documentos no queden rotos.

## Precisión por encima de completitud

Este repo documenta infraestructura que **todavía no está instalada**. Si algo
no está verificado, se marca como pendiente de verificar; no se describe como
si funcionara. Un paso de instalación equivocado cuesta una tarde.

Los archivos de `infra/` y `config/` son plantillas, no configuraciones
probadas. Están marcados como tales y esa marca se mantiene hasta que alguien
las pruebe de verdad.

## Qué no tocar sin pedirlo

- `.gitignore` y `.pre-commit-config.yaml` — son la defensa contra filtrar claves
- Los ADR ya escritos en `docs/decisiones.md` — se agregan nuevos, no se
  reescriben los viejos: son el registro de por qué se decidió lo que se decidió
