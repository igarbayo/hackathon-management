// SPDX-FileCopyrightText: 2023 shadcn
// SPDX-FileCopyrightText: 2026 Ignacio Garbayo
// SPDX-License-Identifier: MIT AND AGPL-3.0-or-later
//
// Generated with the shadcn/ui CLI (https://github.com/shadcn-ui/ui), MIT License:
// full text in LICENSES/MIT.txt. Our own changes are AGPL-3.0-or-later.

"use client"

import * as React from "react"
import { cn } from "cn"

function Label({ className, ...props }: React.ComponentProps<"label">) {
  return (
    <label
      data-slot="label"
      className={cn(
        "flex items-center gap-2 text-sm leading-none font-medium select-none group-data-[disabled=true]:pointer-events-none group-data-[disabled=true]:opacity-50 peer-disabled:cursor-not-allowed peer-disabled:opacity-50",
        className
      )}
      {...props}
    />
  )
}

export { Label }
