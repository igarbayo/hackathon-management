"use client";

import { useState } from "react";
import { useDroppable } from "@dnd-kit/core";
import { SortableContext, verticalListSortingStrategy } from "@dnd-kit/sortable";
import { Input } from "@/components/ui/input";
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
    <div className="flex min-w-64 flex-1 flex-col rounded-lg border">
      <button
        className="flex items-center justify-between border-b p-2 text-sm font-semibold"
        onClick={() => setCollapsed((c) => !c)}
      >
        <span>
          {title} <span className="text-muted-foreground font-normal">({features.length})</span>
        </span>
        <span aria-hidden>{collapsed ? "▸" : "▾"}</span>
      </button>

      {!collapsed && (
        <>
          <div ref={setNodeRef} className="flex min-h-16 flex-1 flex-col gap-2 p-2">
            <SortableContext items={features.map((f) => f.id)} strategy={verticalListSortingStrategy}>
              {features.map((feature) => (
                <FeatureCard key={feature.id} feature={feature} />
              ))}
            </SortableContext>
          </div>
          <form onSubmit={handleQuickCreate} className="border-t p-2">
            <Input
              placeholder="Nueva feature + Enter"
              value={quickTitle}
              onChange={(e) => setQuickTitle(e.target.value)}
              aria-label={`Nueva feature en ${title}`}
            />
          </form>
        </>
      )}
    </div>
  );
}
