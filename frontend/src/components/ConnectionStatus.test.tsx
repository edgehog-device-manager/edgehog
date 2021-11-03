import React from "react";

import { renderWithProviders } from "setupTests";
import ConnectionStatus from "./ConnectionStatus";

it("renders correctly", () => {
  const connectedStatus = renderWithProviders(
    <ConnectionStatus connected={true} />
  );
  const disconnectedStatus = renderWithProviders(
    <ConnectionStatus connected={false} />
  );
  expect(
    connectedStatus.container.querySelector(".text-success")
  ).toBeInTheDocument();
  expect(
    disconnectedStatus.container.querySelector(".text-gray")
  ).toBeInTheDocument();
});
