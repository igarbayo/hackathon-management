import { render, screen } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { AttributionChip } from "../attribution-chip";
import type { Feature } from "@/types/api";

const feature: Feature = {
  id: "f1",
  key: "F-1",
  number: 1,
  title: "Login",
  description: null,
  status: "idea",
  position: 0,
  objective_ids: [],
  assignee_ids: [],
  deadline: null,
  branch_names: [],
  score: 0,
  last_activity_at: null,
  status_changed_at: null,
  updated_at: "",
  created_at: "",
};

describe("AttributionChip", () => {
  it("a confirmed attribution offers no actions", () => {
    render(
      <AttributionChip
        attribution={{ feature_id: "f1", method: "convention", status: "confirmed", confidence: null, reason: null, decided_by_id: null, decided_at: null }}
        features={[feature]}
        onConfirm={vi.fn()}
        onReject={vi.fn()}
        onAssign={vi.fn()}
      />,
    );

    expect(screen.getByText(/F-1/)).toBeInTheDocument();
    expect(screen.queryByRole("button")).not.toBeInTheDocument();
  });

  it("a suggestion offers confirm and reject", async () => {
    const onConfirm = vi.fn();
    const onReject = vi.fn();
    const user = userEvent.setup();

    render(
      <AttributionChip
        attribution={{ feature_id: "f1", method: "ai", status: "suggested", confidence: 0.7, reason: null, decided_by_id: null, decided_at: null }}
        features={[feature]}
        onConfirm={onConfirm}
        onReject={onReject}
        onAssign={vi.fn()}
      />,
    );

    await user.click(screen.getByRole("button", { name: "Confirm" }));
    expect(onConfirm).toHaveBeenCalledOnce();

    await user.click(screen.getByRole("button", { name: "Reject" }));
    expect(onReject).toHaveBeenCalledOnce();
  });

  it("with no attribution it offers a button to assign", async () => {
    const user = userEvent.setup();

    render(<AttributionChip attribution={null} features={[feature]} onConfirm={vi.fn()} onReject={vi.fn()} onAssign={vi.fn()} />);

    expect(screen.getByRole("button", { name: "Assign to…" })).toBeInTheDocument();
    await user.click(screen.getByRole("button", { name: "Assign to…" }));

    expect(screen.getByRole("combobox")).toBeInTheDocument();
  });
});
