"use client";

import { AlertTriangleIcon, type LucideIcon } from "lucide-react";
import { Button } from "@/components/ui/button";
import { Skeleton } from "@/components/ui/skeleton";

// RF-UX-005: every screen has a loading, empty and error state.
// F0 style (OneEmptyState): icon in a circle, title, description and CTA,
// no dashed border — specs/13-sistema-diseno.md.

export function LoadingState({ rows = 3 }: { rows?: number }) {
  return (
    <div className="flex flex-col gap-3" role="status" aria-label="Loading">
      {Array.from({ length: rows }).map((_, i) => (
        <Skeleton key={i} className="h-16 w-full" />
      ))}
    </div>
  );
}

function StateShell({
  icon: Icon,
  iconClassName,
  title,
  description,
  children,
}: {
  icon: LucideIcon;
  iconClassName?: string;
  title: string;
  description?: string;
  children?: React.ReactNode;
}) {
  return (
    <div className="flex flex-col items-center justify-center gap-3 rounded-xl bg-f1-background-tertiary p-10 text-center">
      <div
        className={
          "flex size-10 items-center justify-center rounded-full bg-f1-background-secondary " +
          (iconClassName ?? "text-f1-icon")
        }
      >
        <Icon className="size-5" />
      </div>
      <div className="flex flex-col gap-1">
        <p className="text-base font-medium text-f1-foreground">{title}</p>
        {description && (
          <p className="text-sm text-f1-foreground-secondary">{description}</p>
        )}
      </div>
      {children}
    </div>
  );
}

export function EmptyState({
  icon,
  title,
  description,
  actionLabel,
  onAction,
}: {
  icon: LucideIcon;
  title: string;
  description?: string;
  actionLabel?: string;
  onAction?: () => void;
}) {
  return (
    <StateShell icon={icon} title={title} description={description}>
      {actionLabel && onAction && (
        <Button onClick={onAction} size="sm">
          {actionLabel}
        </Button>
      )}
    </StateShell>
  );
}

export function ErrorState({ message, onRetry }: { message?: string; onRetry: () => void }) {
  return (
    <StateShell
      icon={AlertTriangleIcon}
      iconClassName="text-f1-icon-critical bg-f1-background-critical"
      title="Something went wrong while loading this"
      description={message}
    >
      <Button onClick={onRetry} variant="outline" size="sm">
        Retry
      </Button>
    </StateShell>
  );
}
