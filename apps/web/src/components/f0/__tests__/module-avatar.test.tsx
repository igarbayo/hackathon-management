import { render } from "@testing-library/react";
import { HouseIcon } from "lucide-react";
import { ModuleAvatar } from "../module-avatar";

describe("ModuleAvatar", () => {
  it("renders the icon inside the default color container", () => {
    const { container } = render(<ModuleAvatar icon={HouseIcon} />);
    const wrapper = container.firstElementChild;
    expect(wrapper).toHaveClass("bg-f1-background-secondary");
    expect(wrapper?.querySelector("svg")).toBeInTheDocument();
  });

  it("applies the requested tone", () => {
    const { container } = render(<ModuleAvatar icon={HouseIcon} tone="critical" />);
    expect(container.firstElementChild).toHaveClass("bg-f1-background-critical");
  });
});
