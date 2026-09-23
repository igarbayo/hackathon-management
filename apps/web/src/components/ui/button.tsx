// SPDX-FileCopyrightText: 2023 shadcn
// SPDX-FileCopyrightText: 2026 Ignacio Garbayo
// SPDX-License-Identifier: MIT AND AGPL-3.0-or-later
//
// Generado con la CLI de shadcn/ui (https://github.com/shadcn-ui/ui), MIT License:
// texto completo en LICENSES/MIT.txt. Los cambios propios son AGPL-3.0-or-later.

import { Button as ButtonPrimitive } from "@base-ui/react/button"
import { cva, type VariantProps } from "class-variance-authority"
import { cn } from "cn"
import { Loader2Icon } from "lucide-react"

/**
 * Calcado de F0Button (packages/react/src/ui/Action/variants.ts de F0):
 * colores y estados reales de cada variante, con los nombres de prop de
 * shadcn que ya usa el resto de la app (secondary → neutral, destructive →
 * critical, ver specs/13-sistema-diseno.md). Tamaños según la escala de
 * alturas de F0 (sm 24px, md/default 32px, lg 40px) y su mapeo de radios
 * (sm→rounded-sm, md→rounded, lg→rounded-md).
 */
const buttonVariants = cva(
  "group/button inline-flex shrink-0 items-center justify-center gap-1.5 text-base font-medium whitespace-nowrap transition-colors outline-none select-none active:translate-y-px disabled:pointer-events-none disabled:opacity-30 aria-disabled:pointer-events-none aria-disabled:opacity-30 focus-visible:ring-1 focus-visible:ring-f1-special-ring focus-visible:ring-offset-1 aria-invalid:border-destructive aria-invalid:ring-3 aria-invalid:ring-destructive/20 [&_svg]:pointer-events-none [&_svg]:shrink-0 [&_svg:not([class*='size-'])]:size-4",
  {
    variants: {
      variant: {
        default:
          "bg-f1-background-accent-bold text-f1-foreground-inverse hover:bg-f1-background-accent-bold-hover",
        outline:
          "border border-f1-border bg-f1-background text-f1-foreground hover:bg-f1-background-tertiary hover:border-f1-border-hover aria-expanded:bg-f1-background-tertiary",
        secondary:
          "bg-f1-background-secondary text-f1-foreground hover:bg-f1-background-secondary-hover aria-expanded:bg-f1-background-secondary-hover",
        ghost:
          "text-f1-foreground hover:bg-f1-background-secondary-hover aria-expanded:bg-f1-background-secondary-hover",
        destructive:
          "bg-f1-background-secondary text-f1-foreground-critical hover:bg-f1-background-critical-bold hover:text-f1-foreground-inverse",
        link: "text-f1-foreground underline decoration-f1-border-hover decoration-1 underline-offset-4 hover:decoration-f1-border-bold",
      },
      size: {
        default: "h-8 gap-1.5 rounded px-3",
        xs: "h-6 gap-1 rounded-sm px-2 text-sm",
        sm: "h-6 gap-1 rounded-sm px-2.5 text-sm",
        lg: "h-10 gap-1.5 rounded-md px-4 text-lg",
        icon: "size-8 rounded",
        "icon-xs": "size-6 rounded-sm",
        "icon-sm": "size-6 rounded-sm",
        "icon-lg": "size-10 rounded-md",
      },
    },
    defaultVariants: {
      variant: "default",
      size: "default",
    },
  }
)

function Button({
  className,
  variant = "default",
  size = "default",
  loading = false,
  disabled,
  children,
  ...props
}: ButtonPrimitive.Props &
  VariantProps<typeof buttonVariants> & { loading?: boolean }) {
  return (
    <ButtonPrimitive
      data-slot="button"
      className={cn(buttonVariants({ variant, size, className }))}
      disabled={disabled || loading}
      aria-busy={loading || undefined}
      {...props}
    >
      {loading ? <Loader2Icon className="animate-spin" /> : null}
      {children}
    </ButtonPrimitive>
  )
}

export { Button, buttonVariants }
