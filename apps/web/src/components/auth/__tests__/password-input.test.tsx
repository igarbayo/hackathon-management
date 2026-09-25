import { render, screen } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { PasswordInput } from "@/components/auth/password-input";

describe("PasswordInput", () => {
  it("starts hidden and the eye toggles between showing and hiding it", async () => {
    const user = userEvent.setup();
    render(
      <>
        <label htmlFor="password">Password</label>
        <PasswordInput id="password" defaultValue="supersecret123" />
      </>,
    );

    const input = screen.getByLabelText("Password", { exact: true });
    expect(input).toHaveAttribute("type", "password");

    await user.click(screen.getByRole("button", { name: "Show password" }));
    expect(input).toHaveAttribute("type", "text");

    await user.click(screen.getByRole("button", { name: "Hide password" }));
    expect(input).toHaveAttribute("type", "password");
  });

  it("the eye does not submit the form", async () => {
    const user = userEvent.setup();
    const onSubmit = vi.fn((e: React.FormEvent) => e.preventDefault());
    render(
      <form onSubmit={onSubmit}>
        <PasswordInput id="password" />
      </form>,
    );

    await user.click(screen.getByRole("button", { name: "Show password" }));
    expect(onSubmit).not.toHaveBeenCalled();
  });
});
