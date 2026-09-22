"use client";

import { use, useState } from "react";
import { Activity as ActivityIcon, GitCommit, MessageSquare, Radio, Settings2 } from "lucide-react";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select";
import { Button } from "@/components/ui/button";
import { EmptyState, ErrorState, LoadingState } from "@/components/states";
import { useActivity, useDecideAttribution } from "@/hooks/use-activity";
import { useFeatures } from "@/hooks/use-features";
import { relativeTime } from "@/lib/format-date";
import { AttributionChip } from "./attribution-chip";
import type { ActivityEvent } from "@/types/activity";

const SOURCE_ICON = { github: GitCommit, claude_code: MessageSquare, mcp: Radio, system: Settings2 } as const;

// RF-ACT-010/011/012: feed cronológico con scroll infinito, filtro por
// attribution_status y chip de atribución con acciones.
export default function ActivityPage({ params }: { params: Promise<{ teamId: string }> }) {
  const { teamId } = use(params);
  const [attributionStatus, setAttributionStatus] = useState<string>("all");
  const { data: features } = useFeatures(teamId);
  const decide = useDecideAttribution(teamId);

  const filters = attributionStatus === "all" ? {} : { attribution_status: attributionStatus };
  const { data, isLoading, isError, refetch, fetchNextPage, hasNextPage, isFetchingNextPage } = useActivity(teamId, filters);

  const events = data?.pages.flatMap((page) => page.data) ?? [];

  return (
    <div className="flex flex-col gap-6">
      <div className="flex items-center justify-between">
        <h1 className="text-2xl font-semibold">Actividad</h1>
        <Select value={attributionStatus} onValueChange={(v) => v && setAttributionStatus(v)}>
          <SelectTrigger className="w-44">
            <SelectValue />
          </SelectTrigger>
          <SelectContent>
            <SelectItem value="all">Todos</SelectItem>
            <SelectItem value="none">Sin atribuir</SelectItem>
            <SelectItem value="suggested">Sugeridas</SelectItem>
            <SelectItem value="confirmed">Confirmadas</SelectItem>
          </SelectContent>
        </Select>
      </div>

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
        <ul className="flex flex-col gap-2">
          {events.map((event) => (
            <EventRow
              key={event.id}
              event={event}
              features={features ?? []}
              onConfirm={() => decide.mutate({ eventId: event.id, action: "confirm" })}
              onReject={() => decide.mutate({ eventId: event.id, action: "reject" })}
              onAssign={(featureId) => decide.mutate({ eventId: event.id, action: "set", featureId })}
            />
          ))}
        </ul>
      )}

      {hasNextPage && (
        <Button variant="outline" onClick={() => fetchNextPage()} disabled={isFetchingNextPage}>
          {isFetchingNextPage ? "Cargando…" : "Cargar más"}
        </Button>
      )}
    </div>
  );
}

function EventRow({
  event,
  features,
  onConfirm,
  onReject,
  onAssign,
}: {
  event: ActivityEvent;
  features: import("@/types/api").Feature[];
  onConfirm: () => void;
  onReject: () => void;
  onAssign: (featureId: string) => void;
}) {
  const Icon = SOURCE_ICON[event.source];

  return (
    <li className="flex items-center gap-3 rounded-md border p-2.5 text-sm">
      <Icon className="text-muted-foreground size-4 shrink-0" />
      <span className="flex-1 truncate">
        <span className="font-medium">{event.actor.display ?? "Alguien"}</span> {event.title}
      </span>
      {(event.stats.additions !== undefined || event.stats.deletions !== undefined) && (
        <span className="text-muted-foreground shrink-0 text-xs">
          +{event.stats.additions ?? 0} -{event.stats.deletions ?? 0}
        </span>
      )}
      <span className="text-muted-foreground shrink-0 text-xs">{relativeTime(event.occurred_at)}</span>
      <div className="shrink-0">
        <AttributionChip attribution={event.attribution} features={features} onConfirm={onConfirm} onReject={onReject} onAssign={onAssign} />
      </div>
    </li>
  );
}
