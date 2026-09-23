// SPDX-FileCopyrightText: 2023 shadcn
// SPDX-FileCopyrightText: 2026 Ignacio Garbayo
// SPDX-License-Identifier: MIT AND AGPL-3.0-or-later
//
// Generado con la CLI de shadcn/ui (https://github.com/shadcn-ui/ui), MIT License:
// texto completo en LICENSES/MIT.txt. Los cambios propios son AGPL-3.0-or-later.

import { mergeProps } from "@base-ui/react/merge-props"
import { useRender } from "@base-ui/react/use-render"
import { cva, type VariantProps } from "class-variance-authority"
import { cn } from "cn"

/**
 * Calcado de F0TagStatus / BaseTag (packages/react/src/components/tags/…
 * de F0): forma de píldora, 24px de alto, texto y color de fondo a juego
 * por estado. Se añaden `positive`/`warning`/`info`, que no existían en la
 * paleta de shadcn de partida. Ver specs/13-sistema-diseno.md.
 */
const badgeVariants = cva(
  "group/badge inline-flex h-6 w-fit shrink-0 items-center justify-center gap-1 overflow-hidden rounded-full px-2 py-0.5 text-sm font-medium whitespace-nowrap transition-colors focus-visible:ring-1 focus-visible:ring-f1-special-ring focus-visible:ring-offset-1 has-data-[icon=inline-end]:pr-1.5 has-data-[icon=inline-start]:pl-1.5 [&>svg]:pointer-events-none [&>svg]:size-3.5",
  {
    variants: {
      variant: {
        default: "bg-f1-background-secondary text-f1-foreground-secondary",
        secondary: "bg-f1-background-secondary text-f1-foreground-secondary",
        info: "bg-f1-background-info text-f1-foreground-info",
        positive: "bg-f1-background-positive text-f1-foreground-positive",
        warning: "bg-f1-background-warning text-f1-foreground-warning",
        destructive: "bg-f1-background-critical text-f1-foreground-critical",
        outline: "border border-f1-border text-f1-foreground bg-transparent",
        "outline-dashed":
          "border border-dashed border-f1-border-hover text-f1-foreground bg-transparent",
        ghost: "text-f1-foreground-secondary bg-transparent",
        link: "text-f1-foreground-accent underline-offset-4 hover:underline",
      },
    },
    defaultVariants: {
      variant: "default",
    },
  }
)

function Badge({
  className,
  variant = "default",
  render,
  ...props
}: useRender.ComponentProps<"span"> & VariantProps<typeof badgeVariants>) {
  return useRender({
    defaultTagName: "span",
    props: mergeProps<"span">(
      {
        className: cn(badgeVariants({ variant }), className),
      },
      props
    ),
    render,
    state: {
      slot: "badge",
      variant,
    },
  })
}

export { Badge, badgeVariants }
