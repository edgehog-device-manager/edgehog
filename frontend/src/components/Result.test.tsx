import React from "react";
import { render } from "@testing-library/react";

import Result from "./Result";

it("renders NotFound correctly", () => {
  const imageSrc =
    "data:image/gif;base64,R0lGODlhAQABAIAAAAAAAP///yH5BAEAAAAALAAAAAABAAEAAAIBRAA7";
  const { container } = render(<Result.NotFound image={imageSrc} />);
  const image = container.querySelector("img");
  expect(image).toBeInTheDocument();
  expect(image).toHaveAttribute("src", imageSrc);
});
