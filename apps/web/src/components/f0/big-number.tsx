import type { ReactNode } from "react"
import { cn } from "cn"

const toneClasses = {
  neutral: "text-f1-foreground",
  accent: "text-f1-foreground-accent",
  positive: "text-f1-foreground-positive",
  warning: "text-f1-foreground-warning",
  critical: "text-f1-foreground-critical",
} as const

/** Copied from F0BigNumber: big figure + label, for summary cards. */
function BigNumber({
  value,
  label,
  tone = "neutral",
  className,
}: {
  value: ReactNode
  label: ReactNode
  tone?: keyof typeof toneClasses
  className?: string
}) {
  return (
    <div className={cn("flex flex-col gap-0.5", className)}>
      <span
        className={cn(
          "text-3xl leading-none font-semibold tabular-nums",
          toneClasses[tone]
        )}
      >
        {value}
      </span>
      <span className="text-sm text-f1-foreground-secondary">{label}</span>
    </div>
  )
}

export { BigNumber }
