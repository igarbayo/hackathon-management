"use client";

import { use } from "react";
import { DndContext, PointerSensor, useSensor, useSensors, type DragEndEvent } from "@dnd-kit/core";
import { ErrorState, LoadingState } from "@/components/states";
import { useCreateFeature, useFeatures, useMoveFeature } from "@/hooks/use-features";
import type { FeatureStatus } from "@/types/api";
import { KanbanColumn } from "./kanban-column";

const COLUMNS: { status: FeatureStatus; title: string; collapsedByDefault?: boolean }[] = [
  { status: "idea", title: "Idea" },
  { status: "in_progress", title: "En curso" },
  { status: "done", title: "Hecha" },
  { status: "discarded", title: "Descartada", collapsedByDefault: true },
];

export default function FeaturesPage({ params }: { params: Promise<{ teamId: string }> }) {
  const { teamId } = use(params);
  const { data: features, isLoading, isError, refetch } = useFeatures(teamId);
  const createFeature = useCreateFeature(teamId);
  const moveFeature = useMoveFeature(teamId);

  const sensors = useSensors(useSensor(PointerSensor, { activationConstraint: { distance: 4 } }));

  if (isLoading) return <LoadingState />;
  if (isError) return <ErrorState onRetry={() => refetch()} />;

  const byStatus = (status: FeatureStatus) =>
    (features ?? []).filter((f) => f.status === status).sort((a, b) => a.position - b.position);

  function handleDragEnd(event: DragEndEvent) {
    const { active, over } = event;
    if (!over) return;

    const moved = features?.find((f) => f.id === active.id);
    if (!moved) return;

    const overId = String(over.id);
    let targetStatus: FeatureStatus;
    let beforeId: string | undefined;
    let afterId: string | undefined;

    if (overId.startsWith("column-")) {
      targetStatus = overId.replace("column-", "") as FeatureStatus;
      const column = byStatus(targetStatus).filter((f) => f.id !== moved.id);
      afterId = column.at(-1)?.id;
    } else {
      const overFeature = features?.find((f) => f.id === overId);
      if (!overFeature) return;

      targetStatus = overFeature.status;
      const column = byStatus(targetStatus).filter((f) => f.id !== moved.id);
      const overIndex = column.findIndex((f) => f.id === overFeature.id);
      beforeId = overFeature.id;
      afterId = overIndex > 0 ? column[overIndex - 1].id : undefined;
    }

    if (targetStatus === moved.status && beforeId === undefined && afterId === undefined) return;

    moveFeature.mutate({ key: moved.key, status: targetStatus, before_id: beforeId, after_id: afterId });
  }

  return (
    <div className="flex h-full flex-col gap-4">
      <h1 className="text-2xl font-semibold">Features</h1>

      <DndContext sensors={sensors} onDragEnd={handleDragEnd}>
        <div className="flex flex-1 gap-4 overflow-x-auto">
          {COLUMNS.map((column) => (
            <KanbanColumn
              key={column.status}
              status={column.status}
              title={column.title}
              features={byStatus(column.status)}
              collapsedByDefault={column.collapsedByDefault}
              onQuickCreate={(title) => createFeature.mutate({ title, status: column.status })}
            />
          ))}
        </div>
      </DndContext>
    </div>
  );
}

