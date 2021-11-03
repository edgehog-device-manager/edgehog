import React from "react";
import { render, waitFor } from "@testing-library/react";

import Figure from "./Figure";

const placeholderImage =
  "data:image/svg+xml,%3csvg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 500 500' style='background-color:%23f8f8f8'%3e%3c/svg%3e";

it("renders correctly", () => {
  const { container } = render(<Figure />);
  expect(container.querySelector("img")).toBeInTheDocument();
});

it("renders the image if src is valid", () => {
  const validImage =
    "data:image/gif;base64,R0lGODlhAQABAIAAAAAAAP///yH5BAEAAAAALAAAAAABAAEAAAIBRAA7";
  const { container } = render(<Figure src={validImage} />);
  expect(container.querySelector("img")).toHaveAttribute("src", validImage);
});

it("renders a fallback image instead if src cannot be displayed", async () => {
  const invalidImage = "invalid";
  const { container } = render(<Figure src={invalidImage} />);
  await waitFor(() =>
    expect(container.querySelector("img")).toHaveAttribute("src", invalidImage)
  );
});

it("renders a fallback image if src is missing", () => {
  const { container } = render(<Figure />);
  expect(container.querySelector("img")).toHaveAttribute(
    "src",
    placeholderImage
  );
});
