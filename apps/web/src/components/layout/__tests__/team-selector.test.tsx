import { render, screen } from "@testing-library/react";
import { TeamSelector } from "@/components/layout/team-selector";

vi.mock("next/navigation", () => ({ useRouter: () => ({ push: vi.fn() }) }));

describe("TeamSelector", () => {
  it("with several teams, the trigger shows the current team's name and not its id", () => {
    render(
      <TeamSelector
        currentTeamId="team-2"
        memberships={[
          { team_id: "team-1", team_name: "The Alphas", role: "owner" },
          { team_id: "team-2", team_name: "The Betas", role: "member" },
        ]}
      />,
    );

    const trigger = screen.getByRole("combobox", { name: "Select team" });
    expect(trigger).toHaveTextContent("The Betas");
    expect(trigger).not.toHaveTextContent("team-2");
  });
});
