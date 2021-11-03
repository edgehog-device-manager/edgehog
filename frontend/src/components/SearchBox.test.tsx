import React from "react";

import { renderWithProviders } from "setupTests";
import SearchBox from "./SearchBox";

it("renders correctly", () => {
  const { container } = renderWithProviders(<SearchBox />);
  expect(container.querySelector("input[type='search']")).toBeInTheDocument();
});
