import type { ReactNode } from "react"
import { cn } from "cn"

/**
 * F0 list row: used inside a Card with `divide-y` for objectives,
 * deadlines, members… It replaces the repeated `rounded-md border p-2`
 * pattern from the screens built before F0.
 */
function ListRow({
  children,
  className,
}: {
  children: ReactNode
  className?: string
}) {
  return (
    <div
      className={cn(
        "flex items-center gap-2 px-3 py-2.5 first:rounded-t-xl last:rounded-b-xl hover:bg-f1-background-hover",
        className
      )}
    >
      {children}
    </div>
  )
}

export { ListRow }
