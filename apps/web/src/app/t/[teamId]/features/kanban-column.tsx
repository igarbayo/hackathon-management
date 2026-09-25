"use client";

import { useState } from "react";
import { useDroppable } from "@dnd-kit/core";
import { SortableContext, verticalListSortingStrategy } from "@dnd-kit/sortable";
import { ChevronDownIcon, ChevronRightIcon } from "lucide-react";
import { Input } from "@/components/ui/input";
import { FEATURE_STATUS_META } from "@/lib/feature-status";
import type { Feature, FeatureStatus } from "@/types/api";
import { FeatureCard } from "./feature-card";

export function KanbanColumn({
  status,
  title,
  features,
  collapsedByDefault = false,
  onQuickCreate,
}: {
  status: FeatureStatus;
  title: string;
  features: Feature[];
  collapsedByDefault?: boolean;
  onQuickCreate: (title: string) => void;
}) {
  const { setNodeRef } = useDroppable({ id: `column-${status}` });
  const [collapsed, setCollapsed] = useState(collapsedByDefault);
  const [quickTitle, setQuickTitle] = useState("");

  function handleQuickCreate(e: React.FormEvent) {
    e.preventDefault();
    if (!quickTitle.trim()) return;
    onQuickCreate(quickTitle.trim());
    setQuickTitle("");
  }

  return (
    <div
      data-testid={`kanban-column-${status}`}
      className="flex min-w-64 flex-1 flex-col rounded-lg bg-f1-background-secondary"
    >
      <button
        className="focus-ring flex items-center justify-between gap-2 rounded-t-lg p-2.5 text-base font-semibold text-f1-foreground"
        onClick={() => setCollapsed((c) => !c)}
      >
        <span className="flex items-center gap-1.5">
          {collapsed ? (
            <ChevronRightIcon className="size-4 text-f1-icon" aria-hidden />
          ) : (
            <ChevronDownIcon className="size-4 text-f1-icon" aria-hidden />
          )}
          <span className={`size-2 rounded-full ${FEATURE_STATUS_META[status].dot}`} aria-hidden />
          {title}
        </span>
        <span className="text-sm font-normal text-f1-foreground-secondary">{features.length}</span>
      </button>

      {!collapsed && (
        <>
          <div
            ref={setNodeRef}
            data-testid={`kanban-column-drop-${status}`}
            className="flex min-h-16 flex-1 flex-col gap-2 p-2"
          >
            <SortableContext items={features.map((f) => f.id)} strategy={verticalListSortingStrategy}>
              {features.map((feature) => (
                <FeatureCard key={feature.id} feature={feature} />
              ))}
            </SortableContext>
          </div>
          <form onSubmit={handleQuickCreate} className="p-2 pt-0">
            <Input
              placeholder="New feature + Enter"
              value={quickTitle}
              onChange={(e) => setQuickTitle(e.target.value)}
              aria-label={`New feature in ${title}`}
              className="bg-f1-background"
            />
          </form>
        </>
      )}
    </div>
  );
}
