"use client";

import { use, useState } from "react";
import { DndContext, PointerSensor, useSensor, useSensors, type DragEndEvent } from "@dnd-kit/core";
import { SortableContext, useSortable, verticalListSortingStrategy } from "@dnd-kit/sortable";
import { CSS } from "@dnd-kit/utilities";
import { GripVertical, Target, Trash2 } from "lucide-react";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Badge } from "@/components/ui/badge";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select";
import { EmptyState, ErrorState, LoadingState } from "@/components/states";
import { useCreateObjective, useDeleteObjective, useObjectives, useUpdateObjective } from "@/hooks/use-objectives";
import type { Objective } from "@/types/api";

const PRIORITY_LABEL: Record<Objective["priority"], string> = {
  must: "Must",
  should: "Should",
  could: "Could",
};

export default function ObjectivesPage({ params }: { params: Promise<{ teamId: string }> }) {
  const { teamId } = use(params);
  const { data: objectives, isLoading, isError, refetch } = useObjectives(teamId);
  const createObjective = useCreateObjective(teamId);
  const updateObjective = useUpdateObjective(teamId);
  const deleteObjective = useDeleteObjective(teamId);
  const [newTitle, setNewTitle] = useState("");
  const [showArchived, setShowArchived] = useState(false);

  const sensors = useSensors(useSensor(PointerSensor, { activationConstraint: { distance: 4 } }));

  if (isLoading) return <LoadingState />;
  if (isError) return <ErrorState onRetry={() => refetch()} />;

  const visible = (objectives ?? [])
    .filter((o) => showArchived || !o.archived)
    .sort((a, b) => (a.position ?? 0) - (b.position ?? 0));

  async function handleCreate(e: React.FormEvent) {
    e.preventDefault();
    if (!newTitle.trim()) return;
    await createObjective.mutateAsync({ title: newTitle.trim(), priority: "should" });
    setNewTitle("");
  }

  function handleDragEnd(event: DragEndEvent) {
    const { active, over } = event;
    if (!over || active.id === over.id) return;

    const oldIndex = visible.findIndex((o) => o.id === active.id);
    const newIndex = visible.findIndex((o) => o.id === over.id);
    if (oldIndex === -1 || newIndex === -1) return;

    const before = visible[newIndex > oldIndex ? newIndex : newIndex - 1];
    const after = visible[newIndex > oldIndex ? newIndex + 1 : newIndex];
    const beforePos = before?.position ?? (after?.position ?? 0) - 1;
    const afterPos = after?.position ?? beforePos + 1;

    updateObjective.mutate({ id: visible[oldIndex].id, position: (beforePos + afterPos) / 2 });
  }

  return (
    <div className="flex flex-col gap-6">
      <div className="flex items-center justify-between">
        <h1 className="text-2xl font-semibold">Objetivos</h1>
        <label className="text-muted-foreground flex items-center gap-2 text-sm">
          <input type="checkbox" checked={showArchived} onChange={(e) => setShowArchived(e.target.checked)} />
          Mostrar archivados
        </label>
      </div>

      {visible.length === 0 ? (
        <EmptyState icon={Target} title="Todavía no hay objetivos" description="Añade el primero abajo." />
      ) : (
        <DndContext sensors={sensors} onDragEnd={handleDragEnd}>
          <SortableContext items={visible.map((o) => o.id)} strategy={verticalListSortingStrategy}>
            <ul className="flex flex-col gap-2">
              {visible.map((objective) => (
                <ObjectiveRow
                  key={objective.id}
                  objective={objective}
                  onUpdate={(attrs) => updateObjective.mutate({ id: objective.id, ...attrs })}
                  onDelete={() => deleteObjective.mutate(objective.id)}
                />
              ))}
            </ul>
          </SortableContext>
        </DndContext>
      )}

      <form onSubmit={handleCreate} className="flex gap-2">
        <Input
          placeholder="Nuevo objetivo…"
          value={newTitle}
          onChange={(e) => setNewTitle(e.target.value)}
          aria-label="Título del nuevo objetivo"
        />
        <Button type="submit" disabled={createObjective.isPending}>
          Añadir
        </Button>
      </form>
    </div>
  );
}

function ObjectiveRow({
  objective,
  onUpdate,
  onDelete,
}: {
  objective: Objective;
  onUpdate: (attrs: Record<string, unknown>) => void;
  onDelete: () => void;
}) {
  const { attributes, listeners, setNodeRef, transform, transition } = useSortable({ id: objective.id });
  const [title, setTitle] = useState(objective.title);

  const style = { transform: CSS.Transform.toString(transform), transition };

  return (
    <li ref={setNodeRef} style={style} className="bg-card flex items-center gap-2 rounded-md border p-2">
      <button {...attributes} {...listeners} aria-label="Arrastrar para reordenar" className="text-muted-foreground cursor-grab">
        <GripVertical className="size-4" />
      </button>

      <Badge variant="outline">{objective.key}</Badge>

      <Input
        value={title}
        onChange={(e) => setTitle(e.target.value)}
        onBlur={() => title !== objective.title && onUpdate({ title })}
        className="flex-1"
      />

      <Select value={objective.priority} onValueChange={(priority) => onUpdate({ priority })}>
        <SelectTrigger className="w-28">
          <SelectValue />
        </SelectTrigger>
        <SelectContent>
          {Object.entries(PRIORITY_LABEL).map(([value, label]) => (
            <SelectItem key={value} value={value}>
              {label}
            </SelectItem>
          ))}
        </SelectContent>
      </Select>

      <div className="flex gap-1">
        {Object.entries(objective.feature_count).map(([status, count]) => (
          <Badge key={status} variant="secondary">
            {status}: {count}
          </Badge>
        ))}
      </div>

      <Button variant="ghost" size="sm" onClick={() => onUpdate({ archived: !objective.archived })}>
        {objective.archived ? "Desarchivar" : "Archivar"}
      </Button>
      <Button variant="ghost" size="icon" aria-label="Borrar objetivo" onClick={onDelete}>
        <Trash2 className="size-4" />
      </Button>
    </li>
  );
}
