import React from "react";
import { render } from "@testing-library/react";

import Icon from "./Icon";

it("renders correctly", () => {
  const { container } = render(<Icon icon="circle" />);
  expect(container.querySelector(".fa-circle")).toBeInTheDocument();
});
