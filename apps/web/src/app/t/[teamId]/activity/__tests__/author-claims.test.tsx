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
    sha: null,
    pr_number: null,
    url: null,
    title: "Arregla el login",
    summary: null,
    stats: {},
    mentioned_feature_keys: [],
    attribution: null,
    via: null,
    ...overrides,
  };
}

const members = [
  { id: "m-owner", user_id: "u1", role: "owner", display_name: "Olga", git_identities: [], claude_code: null },
  { id: "m-ana", user_id: "u2", role: "member", display_name: "Ana", git_identities: [], claude_code: null },
] satisfies Member[];

describe("canSelectEvent", () => {
  const member = { membershipId: "m-ana", isOwner: false };
  const owner = { membershipId: "m-owner", isOwner: true };

  it("un miembro puede seleccionar eventos de GitHub sin usuario o suyos, no los de otro", () => {
    expect(canSelectEvent(event(), member)).toBe(true);
    expect(canSelectEvent(event({ actor: { user_id: "u2", membership_id: "m-ana" } }), member)).toBe(true);
    expect(canSelectEvent(event({ actor: { user_id: "u1", membership_id: "m-owner" } }), member)).toBe(false);
  });

  it("un owner puede seleccionar cualquier evento de GitHub", () => {
    expect(canSelectEvent(event({ actor: { user_id: "u2", membership_id: "m-ana" } }), owner)).toBe(true);
  });

  it("nunca se seleccionan eventos que no son de GitHub", () => {
    expect(canSelectEvent(event({ source: "claude_code" }), owner)).toBe(false);
  });
});

describe("SelectionBar", () => {
  beforeEach(() => {
    claimMutate.mockClear();
    unclaimMutate.mockClear();
  });

  it("'Son míos' asigna los eventos elegidos con los futuros incluidos por defecto", async () => {
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

    expect(screen.getByRole("checkbox", { name: "Asignarme también los futuros de estos autores" })).toBeChecked();
    expect(screen.queryByRole("combobox", { name: "Asignar a un miembro" })).not.toBeInTheDocument();
    expect(screen.queryByRole("button", { name: "No son míos" })).not.toBeInTheDocument();

    await user.click(screen.getByRole("button", { name: "Son míos" }));
    expect(claimMutate).toHaveBeenCalledWith(
      { eventIds: ["e1"], membershipId: undefined, includeFuture: true },
      expect.anything(),
    );
  });

  it("un owner ve 'Asignar a…' y 'No son míos' sobre eventos con usuario", () => {
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

    expect(screen.getByRole("combobox", { name: "Asignar a un miembro" })).toBeInTheDocument();
    expect(screen.getByRole("button", { name: "No son míos" })).toBeInTheDocument();
    expect(screen.getByRole("checkbox", { name: "Asignar también los futuros de estos autores" })).toBeChecked();
  });
});
