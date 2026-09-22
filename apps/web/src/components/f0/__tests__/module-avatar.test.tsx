import { render } from "@testing-library/react";
import { HouseIcon } from "lucide-react";
import { ModuleAvatar } from "../module-avatar";

describe("ModuleAvatar", () => {
  it("renderiza el icono dentro del contenedor de color por defecto", () => {
    const { container } = render(<ModuleAvatar icon={HouseIcon} />);
    const wrapper = container.firstElementChild;
    expect(wrapper).toHaveClass("bg-f1-background-secondary");
    expect(wrapper?.querySelector("svg")).toBeInTheDocument();
  });

  it("aplica el tono pedido", () => {
    const { container } = render(<ModuleAvatar icon={HouseIcon} tone="critical" />);
    expect(container.firstElementChild).toHaveClass("bg-f1-background-critical");
  });
});
