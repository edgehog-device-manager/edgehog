/*
 * This file is part of Edgehog.
 *
 * Copyright 2021-2026 SECO Mind Srl
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

import { screen } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { describe, expect, it, vi } from "vitest";

import { renderWithProviders } from "@/setupTests";
import Topbar from "@/components/Topbar";

describe("Topbar Component", () => {
  it("renders the topbar with logo and toggle button", () => {
    renderWithProviders(<Topbar />);

    const header = screen.getByRole("banner");
    expect(header).toBeInTheDocument();

    const logo = screen.getByRole("img", { name: "Clea Edgehog Logo" });
    expect(logo).toBeVisible();

    const button = screen.getByRole("button");
    expect(button).toBeVisible();
  });

  it("calls onToggle when the menu button is clicked", async () => {
    const user = userEvent.setup();
    const onToggleMock = vi.fn();

    renderWithProviders(<Topbar onToggle={onToggleMock} />);

    const button = screen.getByRole("button");
    await user.click(button);

    expect(onToggleMock).toHaveBeenCalledOnce();
  });

  it("does not crash if onToggle is not provided", async () => {
    const user = userEvent.setup();

    renderWithProviders(<Topbar />);

    const button = screen.getByRole("button");

    await expect(user.click(button)).resolves.not.toThrow();
  });
});
