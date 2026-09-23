import { render, screen } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { PasswordInput } from "@/components/auth/password-input";

describe("PasswordInput", () => {
  it("empieza oculta y el ojo alterna entre mostrarla y ocultarla", async () => {
    const user = userEvent.setup();
    render(
      <>
        <label htmlFor="password">Contraseña</label>
        <PasswordInput id="password" defaultValue="supersecret123" />
      </>,
    );

    const input = screen.getByLabelText("Contraseña", { exact: true });
    expect(input).toHaveAttribute("type", "password");

    await user.click(screen.getByRole("button", { name: "Mostrar contraseña" }));
    expect(input).toHaveAttribute("type", "text");

    await user.click(screen.getByRole("button", { name: "Ocultar contraseña" }));
    expect(input).toHaveAttribute("type", "password");
  });

  it("el ojo no envía el formulario", async () => {
    const user = userEvent.setup();
    const onSubmit = vi.fn((e: React.FormEvent) => e.preventDefault());
    render(
      <form onSubmit={onSubmit}>
        <PasswordInput id="password" />
      </form>,
    );

    await user.click(screen.getByRole("button", { name: "Mostrar contraseña" }));
    expect(onSubmit).not.toHaveBeenCalled();
  });
});
