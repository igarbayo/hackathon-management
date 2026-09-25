"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";
import { useSortable } from "@dnd-kit/sortable";
import { CSS } from "@dnd-kit/utilities";
import { ScaleIcon } from "lucide-react";
import { Badge } from "@/components/ui/badge";
import { Avatar, AvatarFallback } from "@/components/ui/avatar";
import { relativeTime } from "@/lib/format-date";
import { cn } from "@/lib/utils";
import type { Feature } from "@/types/api";

// Kanban card inside its column. While dragged it stays as a translucent gap
// where it will land; what follows the cursor is the copy of
// `FeatureCardView` that the page's `DragOverlay` draws.
export function FeatureCard({ feature }: { feature: Feature }) {
  const { attributes, listeners, setNodeRef, transform, transition, isDragging } = useSortable({ id: feature.id });

  return (
    <FeatureCardView
      ref={setNodeRef}
      feature={feature}
      style={{ transform: CSS.Transform.toString(transform), transition, opacity: isDragging ? 0.4 : 1 }}
      {...attributes}
      {...listeners}
    />
  );
}

// RF-FEAT-012: key, title, avatars, deadline, objective chips, score and
// time since the last activity.
export function FeatureCardView({
  feature,
  className,
  ...props
}: { feature: Feature } & React.ComponentProps<"div">) {
  const pathname = usePathname();
  const overdue = feature.deadline && new Date(feature.deadline) < new Date() && !["done", "discarded"].includes(feature.status);

  return (
    <div
      {...props}
      data-testid="feature-card"
      className={cn(
        "flex cursor-grab flex-col gap-1.5 rounded-md border border-f1-border bg-f1-background p-2.5 text-base shadow-none transition-colors hover:border-f1-border-hover",
        className,
      )}
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
            <Badge variant="destructive">Overdue · {new Date(feature.deadline).toLocaleDateString("en-US")}</Badge>
          ) : (
            <span className="text-sm text-f1-foreground-secondary">
              {new Date(feature.deadline).toLocaleDateString("en-US")}
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
