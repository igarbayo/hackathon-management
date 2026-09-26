import { useState } from "react";
import { fireEvent, render, screen } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { DatePicker } from "@/components/ui/date-picker";

function ControlledDatePicker() {
  const [value, setValue] = useState<Date>();
  return <DatePicker id="due-at" value={value} onChange={setValue} />;
}

describe("DatePicker", () => {
  it("with no value, it shows the placeholder text", () => {
    render(<DatePicker id="due-at" />);
    expect(screen.getByRole("button", { name: "Pick a date" })).toBeInTheDocument();
  });

  it("with a controlled value, it shows the formatted date", () => {
    render(<DatePicker id="due-at" value={new Date("2026-12-31T23:59:00")} onChange={() => {}} />);
    expect(screen.getByRole("button", { name: /Dec 31, 2026/ })).toBeInTheDocument();
  });

  it("typing a natural language date and pressing Enter confirms it", async () => {
    const user = userEvent.setup();
    render(<ControlledDatePicker />);

    await user.click(screen.getByRole("button", { name: "Pick a date" }));
    const input = await screen.findByPlaceholderText(/tomorrow at 9/);
    await user.type(input, "2026-12-31T23:59");
    await user.keyboard("{Enter}");

    expect(await screen.findByRole("button", { name: /Dec 31, 2026 · 23:59/ })).toBeInTheDocument();
  });

  it("picking a day keeps the popover open so the time can be set", async () => {
    const user = userEvent.setup();
    render(<ControlledDatePicker />);

    await user.click(screen.getByRole("button", { name: "Pick a date" }));
    await user.click(await screen.findByRole("button", { name: /15th/ }));
    fireEvent.change(screen.getByLabelText("Time"), { target: { value: "14:30" } });
    await user.click(screen.getByRole("button", { name: "Done" }));

    expect(await screen.findByRole("button", { name: /15, \d{4} · 14:30/ })).toBeInTheDocument();
  });

  it("a date chrono-node does not understand confirms nothing", async () => {
    const user = userEvent.setup();
    render(<ControlledDatePicker />);

    await user.click(screen.getByRole("button", { name: "Pick a date" }));
    const input = await screen.findByPlaceholderText(/tomorrow at 9/);
    await user.type(input, "this is not a real date");
    await user.keyboard("{Enter}");

    expect(screen.getByRole("button", { name: "Pick a date" })).toBeInTheDocument();
  });
});
