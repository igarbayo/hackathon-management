import type { ReactNode } from "react"
import { cn } from "cn"
import type { LucideIcon } from "lucide-react"
import { ModuleAvatar } from "./module-avatar"

/**
 * Copied from F0's PageHeader (patterns/ApplicationFrame + Page): module
 * icon and breadcrumbs on the left, actions on the right. Use it at the top
 * of every screen instead of a bare `<h1>`.
 */
function PageHeader({
  icon,
  title,
  breadcrumbs,
  description,
  actions,
  className,
}: {
  icon?: LucideIcon
  title: ReactNode
  breadcrumbs?: ReactNode
  description?: ReactNode
  actions?: ReactNode
  className?: string
}) {
  return (
    <div
      className={cn(
        "flex flex-col gap-3 pb-6 sm:flex-row sm:items-start sm:justify-between",
        className
      )}
    >
      <div className="flex items-start gap-3 min-w-0">
        {icon ? <ModuleAvatar icon={icon} /> : null}
        <div className="flex min-w-0 flex-col gap-0.5">
          {breadcrumbs ? (
            <div className="flex items-center gap-1 text-sm text-f1-foreground-secondary">
              {breadcrumbs}
            </div>
          ) : null}
          <h1 className="truncate text-xl font-semibold text-f1-foreground">
            {title}
          </h1>
          {description ? (
            <p className="text-base text-f1-foreground-secondary">
              {description}
            </p>
          ) : null}
        </div>
      </div>
      {actions ? (
        <div className="flex shrink-0 items-center gap-2">{actions}</div>
      ) : null}
    </div>
  )
}

export { PageHeader }
