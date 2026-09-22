"use client";

import { use, useState } from "react";
import { CalendarClock } from "lucide-react";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { EmptyState, ErrorState, LoadingState } from "@/components/states";
import { useCreateMilestone } from "@/hooks/use-milestones";
import { useTimeline } from "@/hooks/use-milestones";
import type { TimelineItem } from "@/types/api";

// RF-DL-013: vista de lista agrupada por Vencidas / Próximas 6h / Más adelante.
export function groupTimeline(items: TimelineItem[], now = new Date()) {
  const sixHours = new Date(now.getTime() + 6 * 60 * 60 * 1000);

  const overdue = items.filter((i) => i.overdue);
  const soon = items.filter((i) => !i.overdue && new Date(i.due_at) <= sixHours);
  const later = items.filter((i) => !i.overdue && new Date(i.due_at) > sixHours);

  return { overdue, soon, later };
}

export default function DeadlinesPage({ params }: { params: Promise<{ teamId: string }> }) {
  const { teamId } = use(params);
  const { data: items, isLoading, isError, refetch } = useTimeline(teamId);
  const createMilestone = useCreateMilestone(teamId);
  const [title, setTitle] = useState("");
  const [kind, setKind] = useState("checkpoint");
  const [dueAt, setDueAt] = useState("");

  if (isLoading) return <LoadingState />;
  if (isError) return <ErrorState onRetry={() => refetch()} />;

  const { overdue, soon, later } = groupTimeline(items ?? []);

  async function handleCreate(e: React.FormEvent) {
    e.preventDefault();
    if (!title.trim() || !dueAt) return;
    await createMilestone.mutateAsync({ title, kind, due_at: new Date(dueAt).toISOString() });
    setTitle("");
    setDueAt("");
  }

  return (
    <div className="flex flex-col gap-6">
      <h1 className="text-2xl font-semibold">Deadlines</h1>

      {(items ?? []).length === 0 ? (
        <EmptyState icon={CalendarClock} title="No hay milestones ni deadlines todavía" />
      ) : (
        <>
          <Group title="Vencidas" items={overdue} tone="destructive" />
          <Group title="Próximas 6 h" items={soon} tone="warning" />
          <Group title="Más adelante" items={later} tone="default" />
        </>
      )}

      <Card>
        <CardHeader>
          <CardTitle className="text-sm">Nuevo milestone</CardTitle>
        </CardHeader>
        <CardContent>
          <form onSubmit={handleCreate} className="flex flex-wrap items-end gap-2">
            <div className="flex flex-col gap-1">
              <Label htmlFor="m-title">Título</Label>
              <Input id="m-title" value={title} onChange={(e) => setTitle(e.target.value)} />
            </div>
            <div className="flex flex-col gap-1">
              <Label htmlFor="m-kind">Tipo</Label>
              <Select value={kind} onValueChange={(value) => value && setKind(value)}>
                <SelectTrigger id="m-kind" className="w-36">
                  <SelectValue />
                </SelectTrigger>
                <SelectContent>
                  <SelectItem value="checkpoint">Checkpoint</SelectItem>
                  <SelectItem value="demo">Demo</SelectItem>
                  <SelectItem value="submission">Entrega</SelectItem>
                  <SelectItem value="custom">Otro</SelectItem>
                </SelectContent>
              </Select>
            </div>
            <div className="flex flex-col gap-1">
              <Label htmlFor="m-due">Fecha</Label>
              <Input id="m-due" type="datetime-local" value={dueAt} onChange={(e) => setDueAt(e.target.value)} />
            </div>
            <Button type="submit" disabled={createMilestone.isPending}>
              Añadir
            </Button>
          </form>
        </CardContent>
      </Card>
    </div>
  );
}

function Group({ title, items, tone }: { title: string; items: TimelineItem[]; tone: "destructive" | "warning" | "default" }) {
  if (items.length === 0) return null;

  return (
    <div>
      <h2 className="text-muted-foreground mb-2 text-sm font-semibold">{title}</h2>
      <ul className="flex flex-col gap-2">
        {items.map((item) => (
          <li key={`${item.type}-${item.id}`} className="flex items-center gap-3 rounded-md border p-2 text-sm">
            <Badge variant={item.type === "milestone" ? "secondary" : "outline"}>
              {item.type === "milestone" ? item.kind : item.key}
            </Badge>
            <span className="flex-1">{item.title}</span>
            <span
              className={
                tone === "destructive" ? "text-destructive" : tone === "warning" ? "text-amber-600" : "text-muted-foreground"
              }
            >
              {new Date(item.due_at).toLocaleString("es-ES")}
            </span>
          </li>
        ))}
      </ul>
    </div>
  );
}
