"use client";

import { toast } from "sonner";
import { UserCheckIcon } from "lucide-react";
import { Button } from "@/components/ui/button";
import { Card } from "@/components/ui/card";
import { Checkbox } from "@/components/ui/checkbox";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select";
import { useClaimActivity, useUnclaimActivity, useUnlinkedAuthors, type ClaimInput } from "@/hooks/use-activity";
import { ApiError } from "@/lib/api-client";
import type { ActivityEvent, ClaimResult } from "@/types/activity";
import type { Member } from "@/types/api";

// RF-ACT-018 (ADR-0018): unlinked authors, selection of GitHub events and the
// bar with "These are mine", "Not mine" and, for owners, "Assign to…".

export interface Viewer {
  membershipId: string | undefined;
  isOwner: boolean;
}

// A member can only change GitHub events with no user or their own; an owner,
// any GitHub event.
export function canSelectEvent(event: ActivityEvent, viewer: Viewer) {
  if (event.source !== "github") return false;
  if (viewer.isOwner) return true;
  return !event.actor.user_id || event.actor.membership_id === viewer.membershipId;
}

function reportResult(result: ClaimResult, done: string) {
  const count = result.data.length;
  const skipped = result.skipped > 0 ? ` · ${result.skipped} skipped` : "";
  toast.success(`${count} ${count === 1 ? "event" : "events"} ${done}${skipped}`);
}

function reportError(error: unknown) {
  toast.error(error instanceof ApiError ? error.message : "Could not complete the action");
}

export function IncludeFutureCheckbox({
  checked,
  onCheckedChange,
  label = "Also assign me future ones from this author",
}: {
  checked: boolean;
  onCheckedChange: (checked: boolean) => void;
  label?: string;
}) {
  return (
    <label className="flex items-center gap-2 text-base text-f1-foreground">
      <Checkbox checked={checked} onCheckedChange={(value) => onCheckedChange(value === true)} />
      {label}
    </label>
  );
}

export function UnlinkedAuthorsPanel({
  teamId,
  includeFuture,
  onIncludeFutureChange,
}: {
  teamId: string;
  includeFuture: boolean;
  onIncludeFutureChange: (checked: boolean) => void;
}) {
  const { data: authors } = useUnlinkedAuthors(teamId, true);
  const claim = useClaimActivity(teamId);

  if (!authors || authors.length === 0) return null;

  const claimAuthor = (author: ClaimInput["author"]) =>
    claim.mutate({ author, includeFuture }, { onSuccess: (result) => reportResult(result, "assigned to you"), onError: reportError });

  return (
    <Card className="gap-3 p-4">
      <div className="flex flex-col gap-1">
        <h2 className="text-lg font-semibold text-f1-foreground">Unlinked authors</h2>
        <p className="text-base text-f1-foreground-secondary">
          Commits from people who are not team members or who used another email. If any of them is you, assign them to yourself.
        </p>
      </div>
      <ul className="flex flex-col divide-y divide-f1-border-secondary">
        {authors.map((author) => (
          <li key={`${author.github_login ?? ""}|${author.email ?? ""}`} className="flex items-center gap-3 py-2 text-base">
            <div className="min-w-0 flex-1">
              <p className="truncate font-medium text-f1-foreground">
                {author.author_name ?? author.github_login ?? author.email}
              </p>
              <p className="truncate text-sm text-f1-foreground-secondary">
                {[author.github_login && `@${author.github_login}`, author.email].filter(Boolean).join(" · ")} ·{" "}
                {author.event_count} {author.event_count === 1 ? "event" : "events"}
              </p>
            </div>
            <Button
              variant="outline"
              size="sm"
              onClick={() => claimAuthor({ github_login: author.github_login, email: author.email })}
              disabled={claim.isPending}
            >
              <UserCheckIcon /> These are mine
            </Button>
          </li>
        ))}
      </ul>
      <IncludeFutureCheckbox checked={includeFuture} onCheckedChange={onIncludeFutureChange} />
    </Card>
  );
}

export function SelectionBar({
  teamId,
  selectedEvents,
  viewer,
  members,
  includeFuture,
  onIncludeFutureChange,
  onClear,
}: {
  teamId: string;
  selectedEvents: ActivityEvent[];
  viewer: Viewer;
  members: Member[];
  includeFuture: boolean;
  onIncludeFutureChange: (checked: boolean) => void;
  onClear: () => void;
}) {
  const claim = useClaimActivity(teamId);
  const unclaim = useUnclaimActivity(teamId);
  const eventIds = selectedEvents.map((event) => event.id);
  const pending = claim.isPending || unclaim.isPending;
  const canUnclaim = selectedEvents.some(
    (event) => event.actor.membership_id && (viewer.isOwner || event.actor.membership_id === viewer.membershipId),
  );

  const claimFor = (membershipId: string | undefined, done: string) =>
    claim.mutate(
      { eventIds, membershipId, includeFuture },
      {
        onSuccess: (result) => {
          reportResult(result, done);
          onClear();
        },
        onError: reportError,
      },
    );

  const handleUnclaim = () =>
    unclaim.mutate(eventIds, {
      onSuccess: (result) => {
        reportResult(result, "unassigned");
        onClear();
      },
      onError: reportError,
    });

  const otherMembers = members.filter((member) => member.id !== viewer.membershipId);

  return (
    <Card role="region" aria-label="Selected events" className="gap-3 p-3">
      <div className="flex flex-wrap items-center gap-2">
        <span className="mr-auto text-base font-medium text-f1-foreground">
          {selectedEvents.length} selected
        </span>
        <Button variant="ghost" size="sm" onClick={onClear} disabled={pending}>
          Cancel
        </Button>
        {canUnclaim && (
          <Button variant="outline" size="sm" onClick={handleUnclaim} disabled={pending}>
            Not mine
          </Button>
        )}
        {viewer.isOwner && otherMembers.length > 0 && (
          <Select
            value={null}
            onValueChange={(membershipId) => {
              const member = otherMembers.find((m) => m.id === membershipId);
              if (member) claimFor(member.id, `assigned to ${member.display_name}`);
            }}
          >
            <SelectTrigger size="sm" className="w-40" aria-label="Assign to a member" disabled={pending}>
              <SelectValue placeholder="Assign to…" />
            </SelectTrigger>
            <SelectContent>
              {otherMembers.map((member) => (
                <SelectItem key={member.id} value={member.id}>
                  {member.display_name}
                </SelectItem>
              ))}
            </SelectContent>
          </Select>
        )}
        <Button size="sm" onClick={() => claimFor(undefined, "assigned to you")} loading={claim.isPending} disabled={pending}>
          These are mine
        </Button>
      </div>
      {/* An owner can assign to another member: the text does not say "me". */}
      <IncludeFutureCheckbox
        checked={includeFuture}
        onCheckedChange={onIncludeFutureChange}
        label={viewer.isOwner ? "Also assign future ones from these authors" : "Also assign me future ones from these authors"}
      />
    </Card>
  );
}
