import { render, screen } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { canSelectEvent, SelectionBar } from "../author-claims";
import type { ActivityEvent } from "@/types/activity";
import type { Member } from "@/types/api";

const claimMutate = vi.fn();
const unclaimMutate = vi.fn();

vi.mock("@/hooks/use-activity", () => ({
  useClaimActivity: () => ({ mutate: claimMutate, isPending: false }),
  useUnclaimActivity: () => ({ mutate: unclaimMutate, isPending: false }),
  useUnlinkedAuthors: () => ({ data: [] }),
}));

function event(overrides: Partial<ActivityEvent> & { actor?: ActivityEvent["actor"] } = {}): ActivityEvent {
  return {
    id: "e1",
    source: "github",
    kind: "commit",
    occurred_at: "2026-09-23T10:00:00Z",
    actor: { user_id: null, membership_id: null, display: "ana-dev" },
    repository_id: null,
    branch: null,
    branches: [],
    sha: null,
    pr_number: null,
    url: null,
    title: "Fix the login",
    summary: null,
    stats: {},
    mentioned_feature_keys: [],
    attribution: null,
    via: null,
    ...overrides,
  };
}

const members = [
  { id: "m-owner", user_id: "u1", role: "owner", display_name: "Olga", avatar_url: null, git_identities: [], claude_code: null },
  { id: "m-ana", user_id: "u2", role: "member", display_name: "Ana", avatar_url: null, git_identities: [], claude_code: null },
] satisfies Member[];

describe("canSelectEvent", () => {
  const member = { membershipId: "m-ana", isOwner: false };
  const owner = { membershipId: "m-owner", isOwner: true };

  it("a member can select GitHub events with no user or their own, not someone else's", () => {
    expect(canSelectEvent(event(), member)).toBe(true);
    expect(canSelectEvent(event({ actor: { user_id: "u2", membership_id: "m-ana" } }), member)).toBe(true);
    expect(canSelectEvent(event({ actor: { user_id: "u1", membership_id: "m-owner" } }), member)).toBe(false);
  });

  it("an owner can select any GitHub event", () => {
    expect(canSelectEvent(event({ actor: { user_id: "u2", membership_id: "m-ana" } }), owner)).toBe(true);
  });

  it("events that are not from GitHub are never selectable", () => {
    expect(canSelectEvent(event({ source: "claude_code" }), owner)).toBe(false);
  });
});

describe("SelectionBar", () => {
  beforeEach(() => {
    claimMutate.mockClear();
    unclaimMutate.mockClear();
  });

  it("'These are mine' assigns the chosen events, with future ones included by default", async () => {
    const user = userEvent.setup();
    render(
      <SelectionBar
        teamId="t1"
        selectedEvents={[event()]}
        viewer={{ membershipId: "m-ana", isOwner: false }}
        members={members}
        includeFuture
        onIncludeFutureChange={() => {}}
        onClear={() => {}}
      />,
    );

    expect(screen.getByRole("checkbox", { name: "Also assign me future ones from these authors" })).toBeChecked();
    expect(screen.queryByRole("combobox", { name: "Assign to a member" })).not.toBeInTheDocument();
    expect(screen.queryByRole("button", { name: "Not mine" })).not.toBeInTheDocument();

    await user.click(screen.getByRole("button", { name: "These are mine" }));
    expect(claimMutate).toHaveBeenCalledWith(
      { eventIds: ["e1"], membershipId: undefined, includeFuture: true },
      expect.anything(),
    );
  });

  it("an owner sees 'Assign to…' and 'Not mine' on events with a user", () => {
    render(
      <SelectionBar
        teamId="t1"
        selectedEvents={[event({ actor: { user_id: "u2", membership_id: "m-ana" } })]}
        viewer={{ membershipId: "m-owner", isOwner: true }}
        members={members}
        includeFuture
        onIncludeFutureChange={() => {}}
        onClear={() => {}}
      />,
    );

    expect(screen.getByRole("combobox", { name: "Assign to a member" })).toBeInTheDocument();
    expect(screen.getByRole("button", { name: "Not mine" })).toBeInTheDocument();
    expect(screen.getByRole("checkbox", { name: "Also assign future ones from these authors" })).toBeChecked();
  });
});
