"use client";

import { use, useState } from "react";
import { CalendarClockIcon, PlusIcon } from "lucide-react";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { DatePicker } from "@/components/ui/date-picker";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select";
import { Card } from "@/components/ui/card";
import {
  Dialog,
  DialogClose,
  DialogContent,
  DialogFooter,
  DialogHeader,
  DialogTitle,
  DialogTrigger,
} from "@/components/ui/dialog";
import { EmptyState, ErrorState, LoadingState } from "@/components/states";
import { PageHeader } from "@/components/f0/page-header";
import { SectionHeader } from "@/components/f0/section-header";
import { useCreateMilestone } from "@/hooks/use-milestones";
import { useTimeline } from "@/hooks/use-milestones";
import { formatDeadline } from "@/lib/format-date";
import type { TimelineItem } from "@/types/api";

// RF-DL-013: list view grouped into Overdue / Next 6 h / Later.
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
  const [open, setOpen] = useState(false);
  const [title, setTitle] = useState("");
  const [kind, setKind] = useState("checkpoint");
  const [dueAt, setDueAt] = useState<Date>();

  if (isLoading) return <LoadingState />;
  if (isError) return <ErrorState onRetry={() => refetch()} />;

  const { overdue, soon, later } = groupTimeline(items ?? []);

  async function handleCreate(e: React.FormEvent) {
    e.preventDefault();
    if (!title.trim() || !dueAt) return;
    await createMilestone.mutateAsync({ title, kind, due_at: dueAt.toISOString() });
    setTitle("");
    setDueAt(undefined);
    setOpen(false);
  }

  return (
    <div className="flex flex-col gap-6">
      <PageHeader
        icon={CalendarClockIcon}
        title="Deadlines"
        actions={
          <Dialog open={open} onOpenChange={setOpen}>
            <DialogTrigger render={<Button />}>
              <PlusIcon className="size-4" /> New milestone
            </DialogTrigger>
            <DialogContent>
              <DialogHeader>
                <DialogTitle>New milestone</DialogTitle>
              </DialogHeader>
              <form onSubmit={handleCreate} className="flex flex-col gap-3">
                <div className="flex flex-col gap-1.5">
                  <Label htmlFor="m-title">Title</Label>
                  <Input id="m-title" value={title} onChange={(e) => setTitle(e.target.value)} />
                </div>
                <div className="flex flex-col gap-1.5">
                  <Label htmlFor="m-kind">Type</Label>
                  <Select value={kind} onValueChange={(value) => value && setKind(value)}>
                    <SelectTrigger id="m-kind" className="w-full">
                      <SelectValue />
                    </SelectTrigger>
                    <SelectContent>
                      <SelectItem value="checkpoint">Checkpoint</SelectItem>
                      <SelectItem value="demo">Demo</SelectItem>
                      <SelectItem value="submission">Submission</SelectItem>
                      <SelectItem value="custom">Other</SelectItem>
                    </SelectContent>
                  </Select>
                </div>
                <div className="flex flex-col gap-1.5">
                  <Label htmlFor="m-due">Date and time</Label>
                  <DatePicker id="m-due" value={dueAt} onChange={setDueAt} />
                </div>
                <DialogFooter>
                  <DialogClose render={<Button type="button" variant="ghost" />}>Cancel</DialogClose>
                  <Button type="submit" loading={createMilestone.isPending}>
                    Add milestone
                  </Button>
                </DialogFooter>
              </form>
            </DialogContent>
          </Dialog>
        }
      />

      {(items ?? []).length === 0 ? (
        <EmptyState
          icon={CalendarClockIcon}
          title="No milestones or deadlines yet"
          actionLabel="New milestone"
          onAction={() => setOpen(true)}
        />
      ) : (
        <div className="flex flex-col gap-4">
          <Group title="Overdue" items={overdue} tone="critical" />
          <Group title="Next 6 h" items={soon} tone="warning" />
          <Group title="Later" items={later} tone="neutral" />
        </div>
      )}
    </div>
  );
}

function Group({ title, items, tone }: { title: string; items: TimelineItem[]; tone: "critical" | "warning" | "neutral" }) {
  if (items.length === 0) return null;

  const dueClass =
    tone === "critical"
      ? "text-f1-foreground-critical"
      : tone === "warning"
        ? "text-f1-foreground-warning"
        : "text-f1-foreground-secondary";

  return (
    <div className="flex flex-col gap-2">
      <SectionHeader title={title} />
      <Card className="divide-y divide-f1-border-secondary py-0">
        {items.map((item) => (
          <div key={`${item.type}-${item.id}`} className="flex items-center gap-3 px-3 py-2.5">
            <Badge variant={item.type === "milestone" ? "secondary" : "outline"}>
              {item.type === "milestone" ? item.kind : item.key}
            </Badge>
            <span className="flex-1 text-base">{item.title}</span>
            <span className={`text-sm ${dueClass}`}>{formatDeadline(item.due_at)}</span>
          </div>
        ))}
      </Card>
    </div>
  );
}
