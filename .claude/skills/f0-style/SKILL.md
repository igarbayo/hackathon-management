---
name: f0-style
description: "Factorial's F0 design system ported to apps/web (f1-* tokens, typography, radii, shadows, Button/Card/Tag variants, writing rules and CRUD patterns). Trigger: when touching any component, page or Tailwind class in apps/web."
metadata:
  type: project
---

# F0 (Factorial) style in apps/web

`apps/web` follows Factorial's **F0** design system (`github.com/factorialco/f0`), ported as our own tokens — `@factorialco/f0-react` is not installed (see [ADR-0013](../../../specs/decisiones.md#adr-0013) and [specs/13-sistema-diseno.md](../../../specs/13-sistema-diseno.md)). This skill is the quick reference; for any component property that is not here, **do not invent it** — look at the real source code in `https://github.com/factorialco/f0/tree/main/packages/react/src` or ask the Storybook MCP (`https://f0.factorial.dev/mcp`, `get-documentation` tool).

## Golden rule

Never use a raw Tailwind palette color (`bg-emerald-500`, `text-red-600`, `border-amber-400`…) or a hex value in `className`. Always a semantic `f1-*` token (or its shadcn alias: `background`, `foreground`, `border`, `primary`, `destructive`…, which already point to F0 through `@theme inline` in `globals.css`).

## Colors (`f1-*`)

Real source: F0's `packages/core/src/tokens/colors.ts`.

**Foreground:** `f1-foreground`, `-secondary`, `-tertiary`, `-inverse(-secondary)`, `-disabled`, `-accent`, `-critical`, `-info`, `-warning`, `-positive`, `-selected`.

**Background:** `f1-background`, `-hover`, `-disabled`, `-secondary(-hover)`, `-tertiary`, `-inverse(-secondary)`, `-bold`, `-accent(-bold(-hover))`, `-promote(-hover|-bold)`, `-critical(-bold)`, `-info(-bold)`, `-warning(-bold)`, `-positive(-bold)`, `-selected(-secondary|-hover|-bold(-hover))`, `-overlay`.

**Border:** `f1-border`, `-hover`, `-secondary`, `-inverse`, `-bold`, `-promote`, `-selected(-bold)`, `-critical(-bold)`, `-warning(-bold)`, `-info(-bold)`, `-positive(-bold)`.

**Icon:** `f1-icon`, `-secondary`, `-inverse`, `-bold`, `-critical(-bold)`, `-accent`, `-info`, `-warning`, `-positive`, `-promote`, `-selected(-hover)`, `-mood-*`.

**Special:** `f1-special-ring` (focus, viridian), `f1-special-page` (app background, behind the panel), `f1-special-highlight`.

Base palette (HSL, light mode): accent=brand purple `266 41% 39%` (#5E3A8C from the logos; the only deviation from F0, which uses radical `348 80% 50%` — RNF-UI-005, ADR-0015), selected/ring=viridian `184 92% 35%`, critical=red `5 100% 65%`, positive=grass `160 84% 39%`, info=malibu `216 90% 65%`, warning=orange `25 95% 53%`, promote=yellow `38 92% 54%`. Neutrals are translucent navy blue (`--neutral-100: 218 48% 10%`) in light mode; in dark mode they are Discord-like grays (panels `228 6% 20%`, page `225 6% 13%`), the second deviation from F0 (RNF-UI-006).

## Typography

Inter 400/500/600 through `next/font/google`, 14px base.

| Class | Size/line height | Letter spacing |
|---|---|---|
| `text-xs` | .625/.75rem | – |
| `text-sm` | .75/1rem | – |
| `text-base` | .875/1.25rem | -0.005em |
| `text-lg` | 1/1.5rem | -0.01em |
| `text-xl` | 1.125/1.75rem | -0.01em |
| `text-2xl` | 1.375/1.75rem | -0.01em |
| `text-3xl` | 1.625/2rem | -0.01em |
| `text-4xl` | 2.25/2.5rem | -0.02em |

## Radii and interactive heights

- Scale: `2xs` .25rem, `xs` .375rem, `sm` .5rem, `DEFAULT` .625rem, `md` .75rem, `lg` .875rem, `xl` 1rem, `2xl` 1.25rem, `3xl` 1.5rem, `full`.
- Interactive elements (button, input, segmented control): `sm` → `rounded-sm` (24px high), `md`/default → `rounded` (32px high), `lg` → `rounded-md` (40px high).
- A container that wraps interactive elements (the background of a segmented control or a button group) goes up one step: inner `sm` → container `rounded` (DEFAULT), inner `md` → container `rounded-md`, inner `lg` → container `rounded-lg`.
- All borders are 1px solid.

## Shadows

`shadow` (DEFAULT) `0 2px 20px hsl(var(--shadow)/.04)`, `shadow-md` `0 4px 20px /.08`, `shadow-lg` `0 8px 30px /.12`, `shadow-xl` `0 12px 56px /.16`.

## Spacing

4px scale. Between elements: `sm` .25rem, `md` .5rem, `lg` .75rem, `xl` 1rem. Page padding: 24px (`p-6`). Max content width: 712px.

## Focus (accessibility)

Equivalent to F0's `focusRing()`:
```
focus-visible:outline-none focus-visible:ring-1 focus-visible:ring-f1-special-ring focus-visible:ring-offset-1
```
Apply it to every custom interactive element (you do not need it on elements that already inherit focus from an existing shadcn/Base UI primitive). See also the `a11y` skill.

## Button (→ F0Button)

Real source: F0's `packages/react/src/ui/Action/variants.ts`.

- **Variants:** `default` (`f1-background-accent-bold` background, inverse text — it is the primary, brand purple accent), `outline` (`f1-background-inverse-secondary` background + `f1-border` ring), `neutral` (`f1-background-secondary` background), `critical` (`f1-background-secondary` background, `f1-foreground-critical` text, solid `f1-background-critical-bold` on hover), `ghost` (transparent), `promote` (`f1-background-promote` background), `outlinePromote`, `link`.
- **Sizes:** `sm` 24px + `rounded-sm`, `md` (default) 32px + `rounded`, `lg` 40px + `rounded-md`.
- Only one `default` button per section. The primary goes on the right when paired with "Cancel". `critical` is only for irreversible actions and always with confirmation.
- Writing: plain English (RNF-UI-013), sentence case, 1-3 words, imperative verb, name the object in destructive actions ("Delete objective").

## Card (→ F0Card)

Real source: `packages/react/src/components/F0Card/CardInternal.tsx`.

- Base: `bg-f1-background shadow-none` with `border` (use `border-f1-border`, or `border-f1-border-secondary` with the "subtle" variant).
- Interactive (with link/onClick): `hover:border-f1-border-hover hover:shadow-md focus-within:border-f1-border-hover focus-within:shadow-md`.
- Selected: `border-f1-border-selected bg-f1-background-selected-secondary`.
- Title: `text-lg font-semibold text-f1-foreground` (compact: `text-base`). Description: `text-base text-f1-foreground-secondary`.

## Tag (→ F0TagStatus / F0TagRaw / BaseTag)

Real source: `packages/react/src/components/tags/F0TagStatus/F0TagStatus.tsx` and `tags/internal/BaseTag/index.tsx`.

- Shape: `rounded-full` (or `rounded-sm` for `shape="square"`), `py-0.5 px-2`, `text-sm` (size `sm`) or `text-base` (size `md`, rare in tags).
- Status variants with matching background/text/icon color:
  - `neutral`: `bg-f1-background-secondary text-f1-foreground-secondary`, icon `text-f1-icon`
  - `info`: `bg-f1-background-info text-f1-foreground-info`, icon `text-f1-icon-info`
  - `positive`: `bg-f1-background-positive text-f1-foreground-positive`, icon `text-f1-icon-positive`
  - `warning`: `bg-f1-background-warning text-f1-foreground-warning`, icon `text-f1-icon-warning`
  - `critical`: `bg-f1-background-critical text-f1-foreground-critical`, icon `text-f1-icon-critical`
- With no icon, a dot (`aspect-square w-2 rounded-full`) in the matching icon color is shown — this is F0TagDot.

## Sidebar

Real source: `packages/react/src/patterns/Navigation/Sidebar/{Sidebar.tsx,Menu/index.tsx}`.

- The panel floats over the `f1-special-page` background: `shadow-lg ring-1 ring-f1-border-secondary`, `rounded-xl` (12px), 8px from the window edges, `f1-background/60` background with blur.
- Menu item: `rounded py-1.5 pl-1.5 pr-2`, 16px icon (F0Icon `size="md"`). Active: `bg-f1-background-secondary text-f1-foreground` + `text-f1-icon-bold` icon. Inactive on hover: `hover:bg-f1-background-secondary` + `text-f1-icon` icon.

## CRUD patterns (F0's 10 principles)

Source: `packages/react/src/experimental/CrudPatterns/__stories__/{principles,quick-reference}.mdx`.

- **Create lives on the collection, never on an item** (an action in the page/list header, not inside the detail).
- **Edit mirrors create** (same form/container).
- **Destructive actions are hidden by default** — they go in an overflow menu (`DropdownMenu`), not as a standalone button.
- **"Are you sure?" is not a confirmation** — ask for something specific (type the name, pick a reason), not a generic yes/no.
- **Async state lives in the action that triggers it** (`loading` on the button itself), not in a global overlay.
- Choosing a container: trivial edit → inline; centered overlay → default; side panel → when context is needed; page → deep resources; wizard → flows with branches.
- Never the browser's `window.prompt`/`window.confirm`/`alert()` — always our own `Dialog`/`AlertDialog`.

## What we do NOT do (out of scope, see ADR-0013)

There is no `F0Provider`, none of the real F0 components (`ApplicationFrame`, `OneDataCollection`, `F0Avatar`…), nor its i18n or its `motion` animations. This is a visual replica on top of shadcn/Base UI, not the real library.
