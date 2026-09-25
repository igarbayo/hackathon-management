import { cn } from "cn"
import type { LucideIcon } from "lucide-react"

/**
 * Copied from F0AvatarModule/F0AvatarIcon: a Lucide icon inside a colored
 * rounded square, used in page headers and in the activity feed as the
 * source icon. See specs/13-sistema-diseno.md.
 */
const sizeClasses = {
  sm: "size-6 rounded-md [&_svg]:size-3.5",
  default: "size-8 rounded-lg [&_svg]:size-4",
  lg: "size-10 rounded-lg [&_svg]:size-5",
} as const

const toneClasses = {
  neutral: "bg-f1-background-secondary text-f1-icon",
  accent: "bg-f1-background-accent text-f1-icon-accent",
  info: "bg-f1-background-info text-f1-icon-info",
  positive: "bg-f1-background-positive text-f1-icon-positive",
  warning: "bg-f1-background-warning text-f1-icon-warning",
  critical: "bg-f1-background-critical text-f1-icon-critical",
} as const

function ModuleAvatar({
  icon: Icon,
  size = "default",
  tone = "neutral",
  className,
}: {
  icon: LucideIcon
  size?: keyof typeof sizeClasses
  tone?: keyof typeof toneClasses
  className?: string
}) {
  return (
    <div
      className={cn(
        "flex shrink-0 items-center justify-center",
        sizeClasses[size],
        toneClasses[tone],
        className
      )}
    >
      <Icon />
    </div>
  )
}

export { ModuleAvatar }
