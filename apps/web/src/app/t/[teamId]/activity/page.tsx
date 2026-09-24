"use client";

import { use, useMemo, useState } from "react";
import { ActivityIcon, GitCommitIcon, MessageSquareIcon, RadioIcon, Settings2Icon } from "lucide-react";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select";
import { Button } from "@/components/ui/button";
import { Card } from "@/components/ui/card";
import { Checkbox } from "@/components/ui/checkbox";
import { EmptyState, ErrorState, LoadingState } from "@/components/states";
import { PageHeader } from "@/components/f0/page-header";
import { useActivity, useDecideAttribution } from "@/hooks/use-activity";
import { useFeatures } from "@/hooks/use-features";
import { useMe } from "@/hooks/use-me";
import { useMembers } from "@/hooks/use-teams";
import { relativeTime } from "@/lib/format-date";
import { AttributionChip } from "./attribution-chip";
import { canSelectEvent, SelectionBar, UnlinkedAuthorsPanel, type Viewer } from "./author-claims";
import type { ActivityEvent } from "@/types/activity";

// `items` hace que el trigger muestre la etiqueta y no el valor crudo.
const FILTERS = [
  { value: "all", label: "Todos" },
  { value: "none", label: "Sin atribuir" },
  { value: "suggested", label: "Sugeridas" },
  { value: "confirmed", label: "Confirmadas" },
  { value: "unlinked", label: "Autores sin vincular" },
];

const SOURCE_ICON = { github: GitCommitIcon, claude_code: MessageSquareIcon, mcp: RadioIcon, system: Settings2Icon } as const;

// RF-ACT-010/011/012: feed cronológico con scroll infinito, filtro por
// attribution_status y chip de atribución con acciones. RF-ACT-018: filtro de
// autores sin vincular y selección de eventos de GitHub para "Son míos".
export default function ActivityPage({ params }: { params: Promise<{ teamId: string }> }) {
  const { teamId } = use(params);
  const [attributionStatus, setAttributionStatus] = useState<string>("all");
  const [selectedIds, setSelectedIds] = useState<Set<string>>(() => new Set());
  const [includeFuture, setIncludeFuture] = useState(true);
  const { data: features } = useFeatures(teamId);
  const { data: me } = useMe();
  const { data: members } = useMembers(teamId);
  const decide = useDecideAttribution(teamId);

  const unlinkedOnly = attributionStatus === "unlinked";
  const filters =
    attributionStatus === "all" ? {} : unlinkedOnly ? { actor_status: "unlinked" } : { attribution_status: attributionStatus };
  const { data, isLoading, isError, refetch, fetchNextPage, hasNextPage, isFetchingNextPage } = useActivity(teamId, filters);

  const events = useMemo(() => data?.pages.flatMap((page) => page.data) ?? [], [data]);
  const viewer: Viewer = {
    membershipId: members?.find((member) => member.user_id === me?.id)?.id,
    isOwner: me?.memberships.find((membership) => membership.team_id === teamId)?.role === "owner",
  };
  const selectedEvents = events.filter((event) => selectedIds.has(event.id));

  const toggleSelected = (eventId: string, checked: boolean) =>
    setSelectedIds((current) => {
      const next = new Set(current);
      if (checked) next.add(eventId);
      else next.delete(eventId);
      return next;
    });

  return (
    <div className="flex flex-col gap-6">
      <PageHeader
        icon={ActivityIcon}
        title="Actividad"
        actions={
          <Select
            items={FILTERS}
            value={attributionStatus}
            onValueChange={(v) => {
              if (!v) return;
              setAttributionStatus(v);
              setSelectedIds(new Set());
            }}
          >
            <SelectTrigger className="w-44">
              <SelectValue />
            </SelectTrigger>
            <SelectContent>
              {FILTERS.map((filter) => (
                <SelectItem key={filter.value} value={filter.value}>
                  {filter.label}
                </SelectItem>
              ))}
            </SelectContent>
          </Select>
        }
      />

      {unlinkedOnly && (
        <UnlinkedAuthorsPanel teamId={teamId} includeFuture={includeFuture} onIncludeFutureChange={setIncludeFuture} />
      )}

      {selectedEvents.length > 0 && (
        <SelectionBar
          teamId={teamId}
          selectedEvents={selectedEvents}
          viewer={viewer}
          members={members ?? []}
          includeFuture={includeFuture}
          onIncludeFutureChange={setIncludeFuture}
          onClear={() => setSelectedIds(new Set())}
        />
      )}

      {isLoading && <LoadingState />}
      {isError && <ErrorState onRetry={() => refetch()} />}

      {!isLoading && !isError && events.length === 0 && (
        <EmptyState
          icon={ActivityIcon}
          title="Todavía no hay actividad que mostrar"
          description="El feed se llena en cuanto conectéis GitHub o Claude Code, o se registren cambios en el tablero."
        />
      )}

      {events.length > 0 && (
        <Card className="divide-y divide-f1-border-secondary py-0">
          {events.map((event) => (
            <EventRow
              key={event.id}
              event={event}
              features={features ?? []}
              selectable={canSelectEvent(event, viewer)}
              selected={selectedIds.has(event.id)}
              onSelectedChange={(checked) => toggleSelected(event.id, checked)}
              onConfirm={() => decide.mutate({ eventId: event.id, action: "confirm" })}
              onReject={() => decide.mutate({ eventId: event.id, action: "reject" })}
              onAssign={(featureId) => decide.mutate({ eventId: event.id, action: "set", featureId })}
            />
          ))}
        </Card>
      )}

      {hasNextPage && (
        <Button variant="outline" onClick={() => fetchNextPage()} loading={isFetchingNextPage}>
          Cargar más
        </Button>
      )}
    </div>
  );
}

function EventRow({
  event,
  features,
  selectable,
  selected,
  onSelectedChange,
  onConfirm,
  onReject,
  onAssign,
}: {
  event: ActivityEvent;
  features: import("@/types/api").Feature[];
  selectable: boolean;
  selected: boolean;
  onSelectedChange: (checked: boolean) => void;
  onConfirm: () => void;
  onReject: () => void;
  onAssign: (featureId: string) => void;
}) {
  const Icon = SOURCE_ICON[event.source];

  return (
    <div className="flex items-center gap-3 px-3 py-2.5 text-base">
      {/* Hueco fijo para que las filas no seleccionables queden alineadas. */}
      <span className="flex size-4 shrink-0 items-center">
        {selectable && (
          <Checkbox
            checked={selected}
            onCheckedChange={(value) => onSelectedChange(value === true)}
            aria-label={`Seleccionar: ${event.title ?? event.kind}`}
          />
        )}
      </span>
      <Icon className="size-4 shrink-0 text-f1-icon" />
      <span className="flex-1 truncate">
        <span className="font-medium text-f1-foreground">{event.actor.display ?? "Alguien"}</span>
        {event.actor.mapped_by === "manual" && (
          <span
            className="text-sm text-f1-foreground-tertiary"
            title={event.actor.author_name ? `Autor en git: ${event.actor.author_name}` : undefined}
          >
            {" "}· asignado a mano
          </span>
        )}{" "}
        {event.title}
      </span>
      {(event.stats.additions !== undefined || event.stats.deletions !== undefined) && (
        <span className="shrink-0 text-sm text-f1-foreground-secondary">
          +{event.stats.additions ?? 0} -{event.stats.deletions ?? 0}
        </span>
      )}
      <span className="shrink-0 text-sm text-f1-foreground-secondary">{relativeTime(event.occurred_at)}</span>
      <div className="shrink-0">
        <AttributionChip attribution={event.attribution} features={features} onConfirm={onConfirm} onReject={onReject} onAssign={onAssign} />
      </div>
    </div>
  );
}
