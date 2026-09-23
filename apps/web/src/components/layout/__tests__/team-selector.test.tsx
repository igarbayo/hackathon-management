import { render, screen } from "@testing-library/react";
import { TeamSelector } from "@/components/layout/team-selector";

vi.mock("next/navigation", () => ({ useRouter: () => ({ push: vi.fn() }) }));

describe("TeamSelector", () => {
  it("con varios equipos, el trigger muestra el nombre del equipo actual y no su id", () => {
    render(
      <TeamSelector
        currentTeamId="team-2"
        memberships={[
          { team_id: "team-1", team_name: "Los Alfa", role: "owner" },
          { team_id: "team-2", team_name: "Los Beta", role: "member" },
        ]}
      />,
    );

    const trigger = screen.getByRole("combobox", { name: "Seleccionar equipo" });
    expect(trigger).toHaveTextContent("Los Beta");
    expect(trigger).not.toHaveTextContent("team-2");
  });
});
