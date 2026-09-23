---
name: f0-style
description: "Sistema de diseño F0 de Factorial portado a apps/web (tokens f1-*, tipografía, radios, sombras, variantes de Button/Card/Tag, reglas de escritura y patrones CRUD). Trigger: al tocar cualquier componente, página o clase de Tailwind en apps/web."
metadata:
  type: project
---

# Estilo F0 (Factorial) en apps/web

`apps/web` sigue el sistema de diseño **F0** de Factorial (`github.com/factorialco/f0`), portado como tokens propios — no se instala `@factorialco/f0-react` (ver [ADR-0013](../../../specs/decisiones.md#adr-0013) y [specs/13-sistema-diseno.md](../../../specs/13-sistema-diseno.md)). Esta skill es la referencia rápida; para cualquier propiedad de componente que no esté aquí, **no la inventes** — mira el código fuente real en `https://github.com/factorialco/f0/tree/main/packages/react/src` o pregunta al MCP de Storybook (`https://f0.factorial.dev/mcp`, herramienta `get-documentation`).

## Regla de oro

Nunca uses un color de la paleta Tailwind en crudo (`bg-emerald-500`, `text-red-600`, `border-amber-400`…) ni un hex en `className`. Siempre un token `f1-*` semántico (o su alias shadcn: `background`, `foreground`, `border`, `primary`, `destructive`…, que ya apuntan a F0 vía `@theme inline` en `globals.css`).

## Colores (`f1-*`)

Fuente real: `packages/core/src/tokens/colors.ts` de F0.

**Foreground:** `f1-foreground`, `-secondary`, `-tertiary`, `-inverse(-secondary)`, `-disabled`, `-accent`, `-critical`, `-info`, `-warning`, `-positive`, `-selected`.

**Background:** `f1-background`, `-hover`, `-disabled`, `-secondary(-hover)`, `-tertiary`, `-inverse(-secondary)`, `-bold`, `-accent(-bold(-hover))`, `-promote(-hover|-bold)`, `-critical(-bold)`, `-info(-bold)`, `-warning(-bold)`, `-positive(-bold)`, `-selected(-secondary|-hover|-bold(-hover))`, `-overlay`.

**Border:** `f1-border`, `-hover`, `-secondary`, `-inverse`, `-bold`, `-promote`, `-selected(-bold)`, `-critical(-bold)`, `-warning(-bold)`, `-info(-bold)`, `-positive(-bold)`.

**Icon:** `f1-icon`, `-secondary`, `-inverse`, `-bold`, `-critical(-bold)`, `-accent`, `-info`, `-warning`, `-positive`, `-promote`, `-selected(-hover)`, `-mood-*`.

**Special:** `f1-special-ring` (foco, viridian), `f1-special-page` (fondo de la app, detrás del panel), `f1-special-highlight`.

Paleta base (HSL, light mode): accent=morado de marca `266 41% 39%` (#5E3A8C de los logos; la única desviación de F0, que usa radical `348 80% 50%` — RNF-UI-005, ADR-0015), selected/ring=viridian `184 92% 35%`, critical=red `5 100% 65%`, positive=grass `160 84% 39%`, info=malibu `216 90% 65%`, warning=orange `25 95% 53%`, promote=yellow `38 92% 54%`. Los neutros son azul-marino translúcido (`--neutral-100: 218 48% 10%`) en claro; en oscuro son grises tipo Discord (paneles `228 6% 20%`, página `225 6% 13%`), la segunda desviación de F0 (RNF-UI-006).

## Tipografía

Inter 400/500/600 vía `next/font/google`, base 14px.

| Clase | Tamaño/interlineado | Letter-spacing |
|---|---|---|
| `text-xs` | .625/.75rem | – |
| `text-sm` | .75/1rem | – |
| `text-base` | .875/1.25rem | -0.005em |
| `text-lg` | 1/1.5rem | -0.01em |
| `text-xl` | 1.125/1.75rem | -0.01em |
| `text-2xl` | 1.375/1.75rem | -0.01em |
| `text-3xl` | 1.625/2rem | -0.01em |
| `text-4xl` | 2.25/2.5rem | -0.02em |

## Radios y alturas interactivas

- Escala: `2xs` .25rem, `xs` .375rem, `sm` .5rem, `DEFAULT` .625rem, `md` .75rem, `lg` .875rem, `xl` 1rem, `2xl` 1.25rem, `3xl` 1.5rem, `full`.
- Elementos interactivos (botón, input, segmented control): `sm` → `rounded-sm` (24px alto), `md`/default → `rounded` (32px alto), `lg` → `rounded-md` (40px alto).
- Un contenedor que envuelve elementos interactivos (fondo de un segmented control, de un button group) sube un escalón: interior `sm` → contenedor `rounded` (DEFAULT), interior `md` → contenedor `rounded-md`, interior `lg` → contenedor `rounded-lg`.
- Todos los bordes son de 1px sólido.

## Sombras

`shadow` (DEFAULT) `0 2px 20px hsl(var(--shadow)/.04)`, `shadow-md` `0 4px 20px /.08`, `shadow-lg` `0 8px 30px /.12`, `shadow-xl` `0 12px 56px /.16`.

## Espaciado

Escala de 4px. Entre elementos: `sm` .25rem, `md` .5rem, `lg` .75rem, `xl` 1rem. Padding de página: 24px (`p-6`). Ancho máximo de contenido: 712px.

## Foco (accesibilidad)

Equivalente a `focusRing()` de F0:
```
focus-visible:outline-none focus-visible:ring-1 focus-visible:ring-f1-special-ring focus-visible:ring-offset-1
```
Aplícalo a todo elemento interactivo custom (no lo necesitas en elementos que ya heredan el foco de un primitivo shadcn/Base UI existente). Ver también la skill `a11y`.

## Button (→ F0Button)

Fuente real: `packages/react/src/ui/Action/variants.ts` de F0.

- **Variantes:** `default` (fondo `f1-background-accent-bold`, texto inverso — es el primario, acento morado de marca), `outline` (fondo `f1-background-inverse-secondary` + anillo `f1-border`), `neutral` (fondo `f1-background-secondary`), `critical` (fondo `f1-background-secondary`, texto `f1-foreground-critical`, hover sólido `f1-background-critical-bold`), `ghost` (transparente), `promote` (fondo `f1-background-promote`), `outlinePromote`, `link`.
- **Tamaños:** `sm` 24px + `rounded-sm`, `md` (default) 32px + `rounded`, `lg` 40px + `rounded-md`.
- Solo un botón `default` por sección. El primario va a la derecha cuando se empareja con "Cancelar". `critical` es solo para acciones irreversibles y siempre con confirmación.
- Escritura: sentence case, 1-3 palabras, verbo imperativo, nombra el objeto en lo destructivo ("Eliminar objetivo").

## Card (→ F0Card)

Fuente real: `packages/react/src/components/F0Card/CardInternal.tsx`.

- Base: `bg-f1-background shadow-none` con `border` (usa `border-f1-border`, o `border-f1-border-secondary` con la variante "subtle").
- Interactiva (con link/onClick): `hover:border-f1-border-hover hover:shadow-md focus-within:border-f1-border-hover focus-within:shadow-md`.
- Seleccionada: `border-f1-border-selected bg-f1-background-selected-secondary`.
- Título: `text-lg font-semibold text-f1-foreground` (compacta: `text-base`). Descripción: `text-base text-f1-foreground-secondary`.

## Tag (→ F0TagStatus / F0TagRaw / BaseTag)

Fuente real: `packages/react/src/components/tags/F0TagStatus/F0TagStatus.tsx` y `tags/internal/BaseTag/index.tsx`.

- Forma: `rounded-full` (o `rounded-sm` para `shape="square"`), `py-0.5 px-2`, `text-sm` (size `sm`) o `text-base` (size `md`, poco común en tags).
- Variantes de estado con su color de fondo/texto/icono a juego:
  - `neutral`: `bg-f1-background-secondary text-f1-foreground-secondary`, icono `text-f1-icon`
  - `info`: `bg-f1-background-info text-f1-foreground-info`, icono `text-f1-icon-info`
  - `positive`: `bg-f1-background-positive text-f1-foreground-positive`, icono `text-f1-icon-positive`
  - `warning`: `bg-f1-background-warning text-f1-foreground-warning`, icono `text-f1-icon-warning`
  - `critical`: `bg-f1-background-critical text-f1-foreground-critical`, icono `text-f1-icon-critical`
- Sin icono, se muestra un punto (`aspect-square w-2 rounded-full`) del color del icono correspondiente — esto es F0TagDot.

## Sidebar

Fuente real: `packages/react/src/patterns/Navigation/Sidebar/{Sidebar.tsx,Menu/index.tsx}`.

- El panel flota sobre el fondo `f1-special-page`: `shadow-lg ring-1 ring-f1-border-secondary`, `rounded-xl` (12px), separado 8px de los bordes de la ventana, fondo `f1-background/60` con blur.
- Item de menú: `rounded py-1.5 pl-1.5 pr-2`, icono 16px (`size="md"` de F0Icon). Activo: `bg-f1-background-secondary text-f1-foreground` + icono `text-f1-icon-bold`. Inactivo con hover: `hover:bg-f1-background-secondary` + icono `text-f1-icon`.

## Patrones CRUD (10 principios de F0)

Fuente: `packages/react/src/experimental/CrudPatterns/__stories__/{principles,quick-reference}.mdx`.

- **Crear vive en la colección, nunca en un ítem** (acción en la cabecera de página/lista, no dentro del detalle).
- **Editar es el espejo de crear** (mismo formulario/contenedor).
- **Lo destructivo se oculta por defecto** — va en un menú de desbordamiento (`DropdownMenu`), no como botón suelto.
- **"¿Seguro?" no es una confirmación** — pide algo específico (escribir el nombre, elegir un motivo), no un simple sí/no genérico.
- **El estado asíncrono vive en la acción que lo dispara** (`loading` en el propio botón), no en un overlay global.
- Elegir contenedor: edición trivial → inline; overlay centrado → por defecto; panel lateral → cuando hace falta contexto; página → recursos profundos; wizard → flujos con ramas.
- Nunca `window.prompt`/`window.confirm`/`alert()` del navegador — siempre un `Dialog`/`AlertDialog` propio.

## Lo que NO hacemos (fuera de alcance, ver ADR-0013)

No hay `F0Provider`, ni los componentes reales de F0 (`ApplicationFrame`, `OneDataCollection`, `F0Avatar`…), ni su i18n ni sus animaciones con `motion`. Esto es una réplica visual sobre shadcn/Base UI, no la librería real.
