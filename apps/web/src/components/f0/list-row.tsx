import type { ReactNode } from "react"
import { cn } from "cn"

/**
 * Fila de lista F0: usada dentro de una Card con `divide-y` para
 * objetivos, deadlines, miembros… sustituye al patrón repetido
 * `rounded-md border p-2` de las pantallas previas a F0.
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
