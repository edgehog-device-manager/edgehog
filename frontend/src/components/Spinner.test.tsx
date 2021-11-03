import React from "react";
import { screen, render } from "@testing-library/react";

import Spinner from "./Spinner";

it("renders correctly", () => {
  render(<Spinner />);
  expect(screen.getByRole("status")).toBeInTheDocument();
});
