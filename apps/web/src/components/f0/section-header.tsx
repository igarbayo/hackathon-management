import type { ReactNode } from "react"
import { cn } from "cn"

/** Copied from F0's SectionHeader: section title + optional action. */
function SectionHeader({
  title,
  description,
  actions,
  className,
}: {
  title: ReactNode
  description?: ReactNode
  actions?: ReactNode
  className?: string
}) {
  return (
    <div
      className={cn(
        "flex items-center justify-between gap-2",
        className
      )}
    >
      <div className="flex flex-col gap-0.5">
        <h2 className="text-base font-semibold text-f1-foreground">
          {title}
        </h2>
        {description ? (
          <p className="text-sm text-f1-foreground-secondary">
            {description}
          </p>
        ) : null}
      </div>
      {actions ? (
        <div className="flex shrink-0 items-center gap-2">{actions}</div>
      ) : null}
    </div>
  )
}

export { SectionHeader }
