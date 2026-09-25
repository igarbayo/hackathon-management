"use client";

import { use, useMemo, useState } from "react";
import { useRouter, useSearchParams } from "next/navigation";
import { ActivityIcon, GitCommitIcon, MessageSquareIcon, RadioIcon, Settings2Icon, XIcon } from "lucide-react";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select";
import { Button } from "@/components/ui/button";
import { Card } from "@/components/ui/card";
import { Checkbox } from "@/components/ui/checkbox";
import { EmptyState, ErrorState, LoadingState } from "@/components/states";
import { Avatar, AvatarFallback, AvatarImage } from "@/components/ui/avatar";
import { BranchTag } from "@/components/github/branch-tag";
import { PageHeader } from "@/components/f0/page-header";
import { useActivity, useDecideAttribution } from "@/hooks/use-activity";
import { useFeatures } from "@/hooks/use-features";
import { useMe } from "@/hooks/use-me";
import { useMembers } from "@/hooks/use-teams";
import { actorAvatarUrl, actorInitials } from "@/lib/actor-avatar";
import { relativeTime } from "@/lib/format-date";
import { AttributionChip } from "./attribution-chip";
import { canSelectEvent, SelectionBar, UnlinkedAuthorsPanel, type Viewer } from "./author-claims";
import type { ActivityEvent } from "@/types/activity";

// `items` makes the trigger show the label and not the raw value.
const FILTERS = [
  { value: "all", label: "All" },
  { value: "none", label: "Unattributed" },
  { value: "suggested", label: "Suggested" },
  { value: "confirmed", label: "Confirmed" },
  { value: "unlinked", label: "Unlinked authors" },
];

const SOURCE_ICON = { github: GitCommitIcon, claude_code: MessageSquareIcon, mcp: RadioIcon, system: Settings2Icon } as const;

// RF-ACT-010/011/012: chronological feed with infinite scroll, a filter by
// attribution_status and an attribution chip with actions. RF-ACT-018: filter
// for unlinked authors and selection of GitHub events for "These are mine".
export default function ActivityPage({ params }: { params: Promise<{ teamId: string }> }) {
  const { teamId } = use(params);
  const router = useRouter();
  // RF-GH-026: `?branch=` filters by branch (linked from the branch tags).
  const branch = useSearchParams().get("branch") ?? undefined;
  const [attributionStatus, setAttributionStatus] = useState<string>("all");
  const [selectedIds, setSelectedIds] = useState<Set<string>>(() => new Set());
  const [includeFuture, setIncludeFuture] = useState(true);
  const { data: features } = useFeatures(teamId);
  const { data: me } = useMe();
  const { data: members } = useMembers(teamId);
  const decide = useDecideAttribution(teamId);

  const unlinkedOnly = attributionStatus === "unlinked";
  const filters = {
    ...(attributionStatus === "all" ? {} : unlinkedOnly ? { actor_status: "unlinked" } : { attribution_status: attributionStatus }),
    ...(branch ? { branch } : {}),
  };
  const { data, isLoading, isError, refetch, fetchNextPage, hasNextPage, isFetchingNextPage } = useActivity(teamId, filters);

  const events = useMemo(() => data?.pages.flatMap((page) => page.data) ?? [], [data]);
  const viewer: Viewer = {
    membershipId: members?.find((member) => member.user_id === me?.id)?.id,
    isOwner: me?.memberships.find((membership) => membership.team_id === teamId)?.role === "owner",
    githubLogin: me?.github_login,
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
        title="Activity"
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

      {branch && (
        <div className="flex items-center gap-2 text-base text-f1-foreground-secondary">
          Branch
          <BranchTag name={branch} />
          <Button variant="ghost" size="sm" onClick={() => router.replace(`/t/${teamId}/activity`)}>
            <XIcon className="size-3.5" /> Clear filter
          </Button>
        </div>
      )}

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
          title="No activity to show yet"
          description="The feed fills up as soon as you connect GitHub or Claude Code, or someone changes the board."
        />
      )}

      {events.length > 0 && (
        <Card className="divide-y divide-f1-border-secondary py-0">
          {events.map((event) => (
            <EventRow
              key={event.id}
              teamId={teamId}
              event={event}
              features={features ?? []}
              members={members ?? []}
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
          Load more
        </Button>
      )}
    </div>
  );
}

function EventRow({
  teamId,
  event,
  features,
  members,
  selectable,
  selected,
  onSelectedChange,
  onConfirm,
  onReject,
  onAssign,
}: {
  teamId: string;
  event: ActivityEvent;
  features: import("@/types/api").Feature[];
  members: import("@/types/api").Member[];
  selectable: boolean;
  selected: boolean;
  onSelectedChange: (checked: boolean) => void;
  onConfirm: () => void;
  onReject: () => void;
  onAssign: (featureId: string) => void;
}) {
  const Icon = SOURCE_ICON[event.source];
  const actorName = event.actor.display ?? "Someone";
  const avatarUrl = actorAvatarUrl(event.actor, members);

  return (
    <div className="flex items-center gap-3 px-3 py-2.5 text-base">
      {/* Fixed slot so rows that cannot be selected stay aligned. */}
      <span className="flex size-4 shrink-0 items-center">
        {selectable && (
          <Checkbox
            checked={selected}
            onCheckedChange={(value) => onSelectedChange(value === true)}
            aria-label={`Select: ${event.title ?? event.kind}`}
          />
        )}
      </span>
      <Icon className="size-4 shrink-0 text-f1-icon" />
      {/* RF-ACT-010: the actor's photo, or their initials if there is none or it does not load. */}
      <Avatar size="sm" aria-hidden>
        {avatarUrl && <AvatarImage src={avatarUrl} alt="" referrerPolicy="no-referrer" />}
        <AvatarFallback className="bg-f1-background-selected-bold font-medium text-f1-foreground-inverse">
          {actorInitials(actorName)}
        </AvatarFallback>
      </Avatar>
      <span className="flex-1 truncate">
        <span className="font-medium text-f1-foreground">{actorName}</span>
        {event.actor.mapped_by === "manual" && (
          <span
            className="text-sm text-f1-foreground-tertiary"
            title={event.actor.author_name ? `Git author: ${event.actor.author_name}` : undefined}
          >
            {" "}· assigned by hand
          </span>
        )}{" "}
        {event.title}
      </span>
      {event.source === "github" && event.branch && <EventBranches teamId={teamId} event={event} />}
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

// RF-GH-026: the event's branch and, if the commit is on more (e.g. already
// merged), how many more, with the list in the title.
function EventBranches({ teamId, event }: { teamId: string; event: ActivityEvent }) {
  const branch = event.branch as string;
  const others = (event.branches ?? []).filter((name) => name !== branch);
  const href = (name: string) => `/t/${teamId}/activity?branch=${encodeURIComponent(name)}`;

  return (
    <span className="hidden shrink-0 items-center gap-1 sm:flex">
      <BranchTag name={branch} href={href(branch)} />
      {others.length > 0 && (
        <span className="text-sm text-f1-foreground-secondary" title={`Also on: ${others.join(", ")}`}>
          +{others.length}
        </span>
      )}
    </span>
  );
}
