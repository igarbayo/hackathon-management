"use client";

import { use, useState } from "react";
import {
  closestCorners,
  DndContext,
  DragOverlay,
  PointerSensor,
  useSensor,
  useSensors,
  type DragEndEvent,
  type DragOverEvent,
  type DragStartEvent,
  type UniqueIdentifier,
} from "@dnd-kit/core";
import { arrayMove } from "@dnd-kit/sortable";
import { KanbanSquareIcon } from "lucide-react";
import { ErrorState, LoadingState } from "@/components/states";
import { PageHeader } from "@/components/f0/page-header";
import { useCreateFeature, useFeatures, useMoveFeature } from "@/hooks/use-features";
import type { Feature, FeatureStatus } from "@/types/api";
import { FeatureCardView } from "./feature-card";
import { KanbanColumn } from "./kanban-column";

const COLUMNS: { status: FeatureStatus; title: string; collapsedByDefault?: boolean }[] = [
  { status: "idea", title: "Idea" },
  { status: "in_progress", title: "In progress" },
  { status: "done", title: "Done" },
  { status: "discarded", title: "Dropped", collapsedByDefault: true },
];

type Board = Record<FeatureStatus, Feature[]>;

function buildBoard(features: Feature[]): Board {
  const board = Object.fromEntries(COLUMNS.map((c) => [c.status, [] as Feature[]])) as Board;
  for (const feature of features) board[feature.status]?.push(feature);
  for (const column of Object.values(board)) column.sort((a, b) => a.position - b.position);
  return board;
}

function findColumn(board: Board, id: UniqueIdentifier): FeatureStatus | undefined {
  const value = String(id);
  if (value.startsWith("column-")) return value.replace("column-", "") as FeatureStatus;
  return COLUMNS.find((c) => board[c.status].some((f) => f.id === value))?.status;
}

// Same rule as Features::Move in the api, so the optimistic position sorts
// the column the same way the server response will.
function positionBetween(after: Feature | undefined, before: Feature | undefined): number {
  if (after && before) return (after.position + before.position) / 2;
  if (after) return after.position + 1;
  if (before) return before.position - 1;
  return 0;
}

export default function FeaturesPage({ params }: { params: Promise<{ teamId: string }> }) {
  const { teamId } = use(params);
  const { data: features, isLoading, isError, refetch } = useFeatures(teamId);
  const createFeature = useCreateFeature(teamId);
  const moveFeature = useMoveFeature(teamId);

  const sensors = useSensors(useSensor(PointerSensor, { activationConstraint: { distance: 4 } }));

  // RF-FEAT-011: while dragging, the board is drawn from `draft`, where the
  // card already changes column when it passes over it, so on drop there is
  // nothing to animate back. After the drop `draft` is still used until the
  // cache changes (optimistic update of the move), so nothing flickers.
  const [activeId, setActiveId] = useState<string | null>(null);
  const [draft, setDraft] = useState<{ board: Board; source: Feature[] | undefined } | null>(null);

  if (isLoading) return <LoadingState />;
  if (isError) return <ErrorState onRetry={() => refetch()} />;

  const board = draft && (activeId || draft.source === features) ? draft.board : buildBoard(features ?? []);
  const activeFeature = activeId ? features?.find((f) => f.id === activeId) : undefined;

  function handleDragStart(event: DragStartEvent) {
    setActiveId(String(event.active.id));
    setDraft({ board, source: features });
  }

  // Moves the card to the other column as soon as the cursor enters it;
  // useSortable handles reordering within the same column by itself.
  function handleDragOver({ active, over }: DragOverEvent) {
    if (!over) return;

    setDraft((current) => {
      if (!current) return current;
      const from = findColumn(current.board, active.id);
      const to = findColumn(current.board, over.id);
      if (!from || !to || from === to) return current;

      const moving = current.board[from].find((f) => f.id === active.id);
      if (!moving) return current;

      const target = current.board[to];
      let index = target.length;
      const overIndex = target.findIndex((f) => f.id === over.id);
      if (overIndex >= 0) {
        const translated = active.rect.current.translated;
        const below = translated && translated.top > over.rect.top + over.rect.height / 2;
        index = overIndex + (below ? 1 : 0);
      }

      return {
        ...current,
        board: {
          ...current.board,
          [from]: current.board[from].filter((f) => f.id !== active.id),
          [to]: [...target.slice(0, index), { ...moving, status: to }, ...target.slice(index)],
        },
      };
    });
  }

  function handleDragEnd({ active, over }: DragEndEvent) {
    setActiveId(null);

    const original = features?.find((f) => f.id === active.id);
    const status = draft ? findColumn(draft.board, active.id) : undefined;
    if (!draft || !original || !status) {
      setDraft(null);
      return;
    }

    let column = draft.board[status];
    const oldIndex = column.findIndex((f) => f.id === active.id);
    const overIndex = over ? column.findIndex((f) => f.id === over.id) : -1;
    if (overIndex >= 0 && overIndex !== oldIndex) column = arrayMove(column, oldIndex, overIndex);

    const index = column.findIndex((f) => f.id === active.id);
    const after = column[index - 1];
    const before = column[index + 1];

    const originalColumn = buildBoard(features ?? [])[original.status];
    const originalIndex = originalColumn.findIndex((f) => f.id === original.id);
    const unchanged =
      status === original.status &&
      originalColumn[originalIndex - 1]?.id === after?.id &&
      originalColumn[originalIndex + 1]?.id === before?.id;
    if (unchanged) {
      setDraft(null);
      return;
    }

    const position = positionBetween(after, before);
    column = column.map((f) => (f.id === original.id ? { ...f, status, position } : f));
    setDraft({ ...draft, board: { ...draft.board, [status]: column } });

    moveFeature.mutate({ key: original.key, status, before_id: before?.id, after_id: after?.id, position });
  }

  function handleDragCancel() {
    setActiveId(null);
    setDraft(null);
  }

  return (
    <div className="flex h-full flex-col gap-4">
      <PageHeader icon={KanbanSquareIcon} title="Features" className="pb-0" />

      <DndContext
        sensors={sensors}
        collisionDetection={closestCorners}
        onDragStart={handleDragStart}
        onDragOver={handleDragOver}
        onDragEnd={handleDragEnd}
        onDragCancel={handleDragCancel}
      >
        <div className="flex flex-1 gap-4 overflow-x-auto">
          {COLUMNS.map((column) => (
            <KanbanColumn
              key={column.status}
              status={column.status}
              title={column.title}
              features={board[column.status]}
              collapsedByDefault={column.collapsedByDefault}
              onQuickCreate={(title) => createFeature.mutate({ title, status: column.status })}
            />
          ))}
        </div>

        <DragOverlay>
          {activeFeature && (
            <FeatureCardView feature={activeFeature} className="cursor-grabbing border-f1-border-hover shadow-md" />
          )}
        </DragOverlay>
      </DndContext>
    </div>
  );
}
