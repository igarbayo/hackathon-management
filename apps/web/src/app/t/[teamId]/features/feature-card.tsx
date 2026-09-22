"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";
import { useSortable } from "@dnd-kit/sortable";
import { CSS } from "@dnd-kit/utilities";
import { Scale } from "lucide-react";
import { Badge } from "@/components/ui/badge";
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
      className="bg-background hover:border-primary flex cursor-grab flex-col gap-1.5 rounded-md border p-2.5 text-sm"
    >
      <div className="flex items-center justify-between">
        <Badge variant="outline">{feature.key}</Badge>
        {feature.score !== 0 && (
          <span className="text-muted-foreground flex items-center gap-1 text-xs">
            <Scale className="size-3" /> {feature.score}
          </span>
        )}
      </div>

      <Link href={`${pathname}/${feature.key}`} className="font-medium hover:underline" onClick={(e) => e.stopPropagation()}>
        {feature.title}
      </Link>

      {feature.deadline && (
        <span className={overdue ? "text-destructive text-xs" : "text-muted-foreground text-xs"}>
          {new Date(feature.deadline).toLocaleDateString("es-ES")}
        </span>
      )}

      {feature.assignee_ids.length > 0 && (
        <div className="flex -space-x-1">
          {feature.assignee_ids.slice(0, 4).map((id) => (
            <div
              key={id}
              className="bg-muted flex size-5 items-center justify-center rounded-full border text-[10px]"
              title={id}
            >
              {id.slice(-2).toUpperCase()}
            </div>
          ))}
        </div>
      )}

      {feature.last_activity_at && (
        <span className="text-muted-foreground text-xs">Actividad {relativeTime(feature.last_activity_at)}</span>
      )}
    </div>
  );
}
