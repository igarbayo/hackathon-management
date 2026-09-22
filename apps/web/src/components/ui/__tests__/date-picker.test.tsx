import { useState } from "react";
import { render, screen } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { DatePicker } from "@/components/ui/date-picker";

function ControlledDatePicker() {
  const [value, setValue] = useState<Date>();
  return <DatePicker id="due-at" value={value} onChange={setValue} />;
}

describe("DatePicker", () => {
  it("sin valor, muestra el texto de placeholder en español", () => {
    render(<DatePicker id="due-at" />);
    expect(screen.getByRole("button", { name: "Elige una fecha" })).toBeInTheDocument();
  });

  it("con un valor controlado, muestra la fecha formateada", () => {
    render(<DatePicker id="due-at" value={new Date("2026-12-31T23:59:00")} onChange={() => {}} />);
    expect(screen.getByRole("button", { name: /31 dic 2026/ })).toBeInTheDocument();
  });

  it("escribir una fecha en lenguaje natural y pulsar Enter la confirma", async () => {
    const user = userEvent.setup();
    render(<ControlledDatePicker />);

    await user.click(screen.getByRole("button", { name: "Elige una fecha" }));
    const input = await screen.findByPlaceholderText(/mañana a las 9/);
    await user.type(input, "2026-12-31T23:59");
    await user.keyboard("{Enter}");

    expect(await screen.findByRole("button", { name: /31 dic 2026 · 23:59/ })).toBeInTheDocument();
  });

  it("una fecha que chrono-node no entiende no confirma nada", async () => {
    const user = userEvent.setup();
    render(<ControlledDatePicker />);

    await user.click(screen.getByRole("button", { name: "Elige una fecha" }));
    const input = await screen.findByPlaceholderText(/mañana a las 9/);
    await user.type(input, "esto no es una fecha de verdad");
    await user.keyboard("{Enter}");

    expect(screen.getByRole("button", { name: "Elige una fecha" })).toBeInTheDocument();
  });
});
