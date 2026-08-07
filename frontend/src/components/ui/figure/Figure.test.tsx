/*
  This file is part of Edgehog.

  Copyright 2021-2023 SECO Mind Srl

  Licensed under the Apache License, Version 2.0 (the "License");
  you may not use this file except in compliance with the License.
  You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

  Unless required by applicable law or agreed to in writing, software
  distributed under the License is distributed on an "AS IS" BASIS,
  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
  See the License for the specific language governing permissions and
  limitations under the License.

  SPDX-License-Identifier: Apache-2.0
*/

import { it, expect } from "vitest";
import { render, screen, waitFor } from "@testing-library/react";

import Figure from "./Figure";

const placeholderImage =
  "data:image/svg+xml,%3csvg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 500 500' style='background-color:%23f8f8f8'%3e%3c/svg%3e";

it("renders correctly", () => {
  render(<Figure />);
  expect(screen.getByRole("img")).toBeVisible();
});

it("renders the image if src is valid", () => {
  const validImage =
    "data:image/gif;base64,R0lGODlhAQABAIAAAAAAAP///yH5BAEAAAAALAAAAAABAAEAAAIBRAA7";
  render(<Figure src={validImage} />);

  expect(screen.getByRole("img")).toHaveAttribute("src", validImage);
});

it("renders a fallback image instead if src cannot be displayed", async () => {
  const invalidImage = "invalid";
  render(<Figure src={invalidImage} />);

  const image = screen.getByRole("img");
  image.dispatchEvent(new Event("error"));
  await waitFor(() =>
    expect(screen.getByRole("img")).toHaveAttribute("src", placeholderImage),
  );
});

it("renders a fallback image if src is missing", () => {
  render(<Figure />);
  expect(screen.getByRole("img")).toHaveAttribute("src", placeholderImage);
});
