import React from "react";
import { screen } from "@testing-library/react";

import { renderWithProviders } from "setupTests";
import App from "./App";

test("renders correctly", () => {
  renderWithProviders(<App />);
  const app = screen.getByTestId("app");
  expect(app).toBeInTheDocument();
});
