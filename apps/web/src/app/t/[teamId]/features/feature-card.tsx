"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";
import { useSortable } from "@dnd-kit/sortable";
import { CSS } from "@dnd-kit/utilities";
import { ScaleIcon } from "lucide-react";
import { Badge } from "@/components/ui/badge";
import { Avatar, AvatarFallback } from "@/components/ui/avatar";
import { relativeTime } from "@/lib/format-date";
import type { Feature } from "@/types/api";

// RF-FEAT-012: clave, título, avatares, deadline, chips de objetivos, score y
// tiempo desde la última actividad.
export function FeatureCard({ feature }: { feature: Feature }) {
  const pathname = usePathname();
  const { attributes, listeners, setNodeRef, transform, transition, isDragging } = useSortable({ id: feature.id });

  const style = { transform: CSS.Transform.toString(transform), transition, opacity: isDragging ? 0.5 : 1 };
  const overdue = feature.deadline && new Date(feature.deadline) < new Date() && !["done", "discarded"].includes(feature.status);

  return (
    <div
      ref={setNodeRef}
      style={style}
      {...attributes}
      {...listeners}
      data-testid="feature-card"
      className="flex cursor-grab flex-col gap-1.5 rounded-md border border-f1-border bg-f1-background p-2.5 text-base shadow-none transition-colors hover:border-f1-border-hover"
    >
      <div className="flex items-center justify-between">
        <Badge variant="outline">{feature.key}</Badge>
        {feature.score !== 0 && (
          <span className="flex items-center gap-1 text-sm text-f1-foreground-secondary">
            <ScaleIcon className="size-3" /> {feature.score}
          </span>
        )}
      </div>

      <Link
        href={`${pathname}/${feature.key}`}
        className="font-medium text-f1-foreground hover:underline"
        onClick={(e) => e.stopPropagation()}
      >
        {feature.title}
      </Link>

      {feature.deadline && (
        <span>
          {overdue ? (
            <Badge variant="destructive">Vencida · {new Date(feature.deadline).toLocaleDateString("es-ES")}</Badge>
          ) : (
            <span className="text-sm text-f1-foreground-secondary">
              {new Date(feature.deadline).toLocaleDateString("es-ES")}
            </span>
          )}
        </span>
      )}

      <div className="flex items-center justify-between">
        {feature.assignee_ids.length > 0 ? (
          <div className="flex -space-x-1.5">
            {feature.assignee_ids.slice(0, 4).map((id) => (
              <Avatar key={id} size="sm" title={id}>
                <AvatarFallback>{id.slice(-2).toUpperCase()}</AvatarFallback>
              </Avatar>
            ))}
          </div>
        ) : (
          <span />
        )}

        {feature.last_activity_at && (
          <span className="text-sm text-f1-foreground-secondary">{relativeTime(feature.last_activity_at)}</span>
        )}
      </div>
    </div>
  );
}
