# 13 · Sistema de diseño

> **Estado de implementación:** En proceso · **Última actualización:** 2026-09-23

`apps/web` sigue el sistema de diseño **F0** de Factorial (`github.com/factorialco/f0`, docs en `f0.factorial.dev`). Ver [ADR-0013](decisiones.md#adr-0013) para la decisión de no instalar `@factorialco/f0-react` y portar sus tokens en su lugar.

## Tokens — `RNF-UI`

| ID | Requisito | Estado |
|----|-----------|--------|
| RNF-UI-001 | Los colores se expresan con los tokens semánticos `f1-*` (`text-f1-foreground`, `bg-f1-background-critical`…), copiados de `@factorialco/f0-core@2.7.0` (`packages/core/src/tokens/colors.ts`), en `apps/web/src/app/globals.css`. Prohibido usar colores de la paleta Tailwind en crudo (`bg-emerald-500`, `text-amber-600`…) o valores hexadecimales en `className`. La única vía de escape son estilos inline documentados, igual que en F0. | Aceptado [F1] |
| RNF-UI-002 | Tipografía Inter (pesos 400, 500 y 600 vía `next/font/google`) con la escala F0 (`xs` a `4xl`, tamaño base 14px/0.875rem). | Aceptado [F1] |
| RNF-UI-003 | Radios (`2xs` 0.25rem … `3xl` 1.5rem) y sombras (`shadow`, `md`, `lg`, `xl`, todas `hsl(var(--shadow)/α)`) según `packages/core/src/tokens/borderRadius.ts` y `shadows.ts` de F0. Los elementos interactivos siguen el mapeo de F0: tamaño `sm` → `rounded-sm`, `md` → `rounded`, `lg` → `rounded-md`. | Aceptado [F1] |
| RNF-UI-004 | Iconos: Lucide (no el set propio de F0), con los tamaños de F0 (`size-4` = `md`, `size-3` = `sm`) y dentro de los mismos contenedores (avatar de módulo, tag) que usa F0 con sus propios iconos. | Aceptado [F1] |

## Escritura y patrones — `RNF-UI`

| ID | Requisito | Estado |
|----|-----------|--------|
| RNF-UI-010 | Textos de botones y acciones en *sentence case*, 1-3 palabras, verbo imperativo. Las acciones destructivas nombran el objeto ("Eliminar objetivo", nunca solo "Eliminar"). Un único botón `default` (primario) por sección; el primario va a la derecha cuando se empareja con un "Cancelar". | Aceptado [F1] |
| RNF-UI-011 | Patrones CRUD de F0: crear vive a nivel de colección (no en un ítem), lo destructivo se oculta por defecto en un menú de desbordamiento y siempre pide confirmación explícita (nunca `window.confirm`/`prompt`/`alert` del navegador). El estado asíncrono (`loading`) vive en la propia acción que lo dispara, no en un overlay global. | Aceptado [F1] |
| RNF-UI-012 | Accesibilidad WCAG 2.1/2.2 AA: contraste de los tokens en ambos temas, foco visible (`focus-visible:ring-1 ring-f1-special-ring ring-offset-1`, equivalente a `focusRing()` de F0) en todo elemento interactivo, roles nativos para checkbox/radio/dialog (nada de `<input>`/`<button>` a pelo simulando un control). | Aceptado [F1] |

## No funcionales — `RNF-UI`

| ID | Requisito | Estado |
|----|-----------|--------|
| RNF-UI-020 | Los tests e2e (Playwright) no seleccionan elementos por nombre de clase de Tailwind; usan `data-testid`, roles o texto accesible, para que el markup se pueda restilar sin romper los tests. | Aceptado [F1] |

## Mapeo de tokens shadcn → F0

Los primitivos de `components/ui` siguen usando los nombres de variable de shadcn (`background`, `foreground`, `border`…) para no tener que tocar cada componente; esos nombres se redefinen en `@theme inline` para apuntar a los tokens F0 en vez de al gris por defecto:

| shadcn | F0 |
|---|---|
| `background` | `f1-background` |
| `foreground` | `f1-foreground` |
| `muted-foreground` | `f1-foreground-secondary` |
| `border`, `input` | `f1-border` |
| `ring` | `f1-special-ring` |
| `primary` | `f1-background-bold` |
| `destructive` | `f1-*-critical` |
| `sidebar` | `f1-special-page` |

Se añaden además los tokens `positive`, `warning` e `info`, ausentes en la paleta shadcn de partida.

## Fuera de alcance

No se instala `@factorialco/f0-react` (ver ADR-0013): no hay `F0Provider`, ni sus componentes de aplicación (`ApplicationFrame`, `OneDataCollection`), ni sus utilidades de i18n/motion. Los componentes de este repo replican su aspecto visual, no su implementación.
