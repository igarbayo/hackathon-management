import type { ReactNode } from "react"
import { cn } from "cn"
import {
  CircleAlertIcon,
  InfoIcon,
  CircleCheckIcon,
  TriangleAlertIcon,
  XIcon,
  type LucideIcon,
} from "lucide-react"
import { Button } from "@/components/ui/button"

/**
 * Calcado de F0Alert (packages/react/src/components/F0Alert/F0Alert.tsx):
 * fondo de tono suave, icono, título y descripción, con acción y cierre
 * opcionales. Ver specs/13-sistema-diseno.md.
 */
const variantClasses = {
  neutral: {
    container: "bg-f1-background-tertiary",
    title: "text-f1-foreground",
    icon: "text-f1-icon",
    Icon: InfoIcon,
  },
  info: {
    container: "bg-f1-background-info",
    title: "text-f1-foreground-info",
    icon: "text-f1-icon-info",
    Icon: InfoIcon,
  },
  positive: {
    container: "bg-f1-background-positive",
    title: "text-f1-foreground-positive",
    icon: "text-f1-icon-positive",
    Icon: CircleCheckIcon,
  },
  warning: {
    container: "bg-f1-background-warning",
    title: "text-f1-foreground-warning",
    icon: "text-f1-icon-warning",
    Icon: TriangleAlertIcon,
  },
  critical: {
    container: "bg-f1-background-critical",
    title: "text-f1-foreground-critical",
    icon: "text-f1-icon-critical",
    Icon: CircleAlertIcon,
  },
} as const

function Alert({
  title,
  description,
  variant = "neutral",
  icon,
  action,
  onClose,
  className,
}: {
  title: ReactNode
  description?: ReactNode
  variant?: keyof typeof variantClasses
  icon?: LucideIcon
  action?: ReactNode
  onClose?: () => void
  className?: string
}) {
  const { container, title: titleClass, icon: iconClass, Icon } =
    variantClasses[variant]
  const IconComponent = icon ?? Icon
  const role = variant === "critical" || variant === "warning" ? "alert" : "status"

  return (
    <div
      role={role}
      className={cn(
        "flex w-full items-start gap-2 rounded-md p-2 pr-3",
        container,
        className
      )}
    >
      <IconComponent className={cn("mt-0.5 size-4 shrink-0", iconClass)} />
      <div className="flex flex-1 flex-col gap-0.5 min-w-0">
        <p className={cn("text-base font-medium", titleClass)}>{title}</p>
        {description ? (
          <p className="text-base text-f1-foreground-secondary">
            {description}
          </p>
        ) : null}
      </div>
      {action}
      {onClose ? (
        <Button
          variant="outline"
          size="icon-sm"
          onClick={onClose}
          aria-label="Cerrar aviso"
        >
          <XIcon />
        </Button>
      ) : null}
    </div>
  )
}

export { Alert }
