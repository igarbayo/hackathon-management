// SPDX-FileCopyrightText: 2023 shadcn
// SPDX-FileCopyrightText: 2026 Ignacio Garbayo
// SPDX-License-Identifier: MIT AND AGPL-3.0-or-later
//
// Generated with the shadcn/ui CLI (https://github.com/shadcn-ui/ui), MIT License:
// full text in LICENSES/MIT.txt. Our own changes are AGPL-3.0-or-later.

import { cn } from "cn"

function Skeleton({ className, ...props }: React.ComponentProps<"div">) {
  return (
    <div
      data-slot="skeleton"
      className={cn("animate-pulse rounded-md bg-muted", className)}
      {...props}
    />
  )
}

export { Skeleton }
