"use client";

import { AlertTriangle, type LucideIcon } from "lucide-react";
import { Button } from "@/components/ui/button";
import { Skeleton } from "@/components/ui/skeleton";

// RF-UX-005: toda pantalla tiene estado de carga, vacío y error.

export function LoadingState({ rows = 3 }: { rows?: number }) {
  return (
    <div className="flex flex-col gap-3" role="status" aria-label="Cargando">
      {Array.from({ length: rows }).map((_, i) => (
        <Skeleton key={i} className="h-16 w-full" />
      ))}
    </div>
  );
}

export function EmptyState({
  icon: Icon,
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
    <div className="flex flex-col items-center justify-center gap-3 rounded-lg border border-dashed p-10 text-center">
      <Icon className="text-muted-foreground size-8" />
      <p className="font-medium">{title}</p>
      {description && <p className="text-muted-foreground text-sm">{description}</p>}
      {actionLabel && onAction && (
        <Button onClick={onAction} size="sm">
          {actionLabel}
        </Button>
      )}
    </div>
  );
}

export function ErrorState({ message, onRetry }: { message?: string; onRetry: () => void }) {
  return (
    <div className="flex flex-col items-center justify-center gap-3 rounded-lg border border-dashed p-10 text-center">
      <AlertTriangle className="text-destructive size-8" />
      <p className="font-medium">Algo falló al cargar esto</p>
      {message && <p className="text-muted-foreground text-sm">{message}</p>}
      <Button onClick={onRetry} variant="outline" size="sm">
        Reintentar
      </Button>
    </div>
  );
}
