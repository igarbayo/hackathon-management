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
| RNF-UI-005 | **Acento de marca:** la única desviación de la paleta de F0. `--accent-50/60/70` usan el morado de los logos (`#5E3A8C` = `266 41% 39%`) en lugar del radical (`348 80% 50%`) de F0; en modo oscuro se aclaran (`266 41% 45%` / `266 45% 55%` / `266 60% 75%`) para mantener el contraste AA sobre el fondo oscuro. Afecta a todo lo que usa los tokens `*-accent*` (botón primario, `f1-foreground-accent`, `f1-special-highlight`…). `--mood-super-negative` y los categóricos de gráficos no cambian: tienen significado propio, no son marca. Ver [ADR-0015](decisiones.md#adr-0015). | Implementado |
| RNF-UI-006 | **Neutros grises en modo oscuro:** segunda desviación de la paleta de F0. F0 tiñe el modo oscuro de azul marino (`--neutral-0: 218 48% 10%`); aquí los neutros oscuros son grises casi puros, con los tonos de la interfaz oscura de Discord: `--neutral-0` (fondo de paneles, tarjetas y popovers) `228 6% 20%` (#313338), `--page` (fondo detrás de los paneles) `225 6% 13%` (#1e1f22), `--neutral-2/3` blancos translúcidos y sombras negras. El resto de neutros ya eran blancos translúcidos y no cambian. El modo claro sigue siendo el de F0. Ver [ADR-0017](decisiones.md#adr-0017). | Implementado |

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

## Selector de fecha — `RNF-UI-030`

| ID | Requisito | Estado |
|----|-----------|--------|
| RNF-UI-030 | Todo campo de fecha u hora de la app usa `DatePicker` (`apps/web/src/components/ui/date-picker.tsx`). Prohibido un `<input type="date">`/`type="datetime-local"` nativo suelto para captura de fecha en una pantalla de producto. | Aceptado [F1] |

`DatePicker` está adaptado de [a-good-date-picker](https://github.com/gulipad/a-good-date-picker) (Guli Moreno, MIT License). Ese repo **no es un paquete npm**: es un componente de un solo fichero pensado para copiarse a mano (estilo shadcn/ui), sin props (estado interno fijo) y sin español en la rama `main` — el propio README documenta props (`value`/`onChange`/`locale`) que no existen en el código. Se han portado a mano los cambios de la [PR #2 del repo](https://github.com/gulipad/a-good-date-picker/pull/2) (props controladas + locale `es`/`en`), sustituyendo sus primitivos (Radix, `react-day-picker@8`) por los de este repo (Base UI, `react-day-picker@10`, ya restilados a F0), y se añaden dos cosas que el original no tenía:

- **se conserva la hora** al elegir solo el día en el calendario (o se pone 23:59 si no había ninguna) — clicar un día no debe borrar una hora ya escrita;
- **`disabled`** (día mínimo/máximo o una función), pasado directamente a `react-day-picker`.

**Uso:**

```tsx
import { DatePicker } from "@/components/ui/date-picker";

const [endsAt, setEndsAt] = useState<Date>();

<Label htmlFor="ends-at">Fecha de fin</Label>
<DatePicker id="ends-at" value={endsAt} onChange={setEndsAt} disabled={{ before: new Date() }} />
```

- `id` asocia el `<Label htmlFor>` con el botón disparador (un botón es un elemento etiquetable en HTML) y, por eso, ese es también el **nombre accesible** que hay que usar en los tests (`getByLabel("Fecha de fin")`), no el texto del botón ("Elige una fecha"). El campo de texto en lenguaje natural, que solo existe en el DOM con el popover abierto, se localiza con `#{id}-search`.
- Escribir una fecha ISO (`2026-12-31T23:59`) en ese campo y pulsar Enter también funciona — `chrono-node` la entiende igual que "mañana a las 9" — así que los e2e existentes solo tuvieron que añadir el click que abre el popover y el `press("Enter")` que antes no hacía falta con el `<input>` nativo.
- Sin `value`/`onChange`, el componente funciona en modo no controlado (estado interno), como el original.

**Fuera de alcance:** rango de fechas (el `Calendar` subyacente lo admite en `mode="range"`, pero `DatePicker` solo expone `mode="single"`) y el prop `locale="en"` no se usa en ningún sitio de la app hoy (queda listo por si hiciera falta, ver PR#2 del repo original).

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
