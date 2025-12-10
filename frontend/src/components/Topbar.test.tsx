/*
 * This file is part of Edgehog.
 *
 * Copyright 2021-2023, 2025 SECO Mind Srl
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *    http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 *
 * SPDX-License-Identifier: Apache-2.0
 */

import { it, expect } from "vitest";

import { screen, queryByAttribute } from "@testing-library/react";
import userEvent from "@testing-library/user-event";

import { renderWithProviders } from "@/setupTests";
import Topbar from "./Topbar";

it("renders correctly", async () => {
  renderWithProviders(<Topbar />);
  const navbar = screen.getByRole("navigation");
  expect(navbar).toBeInTheDocument();

  expect(screen.getByRole("img", { name: "Logo" })).toBeVisible();

  expect(
    screen.queryByRole("link", { name: "Logout" }),
  ).not.toBeInTheDocument();

  const dropdown = queryByAttribute("data-icon", navbar, "angle-down");
  expect(dropdown).not.toBeNull();
  expect(dropdown).toBeVisible();
  await userEvent.click(dropdown!);

  expect(screen.getByRole("link", { name: "Logout" })).toBeVisible();
});
