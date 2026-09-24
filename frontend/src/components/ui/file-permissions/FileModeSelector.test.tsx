/*
  This file is part of Edgehog.

  Copyright 2026 SECO Mind Srl

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

import { describe, expect, it, vi } from "vitest";
import { screen } from "@testing-library/react";
import userEvent from "@testing-library/user-event";

import { renderWithProviders } from "@/setupTests";
import FileModeSelector from "./FileModeSelector";

describe("FileModeSelector", () => {
  it("renders with initial value and displays symbolic and octal representation", () => {
    // 493 is 0755: rwxr-xr-x
    renderWithProviders(<FileModeSelector value={493} onChange={vi.fn()} />);

    expect(screen.getByText("rwxr-xr-x")).toBeInTheDocument();
    expect(screen.getByDisplayValue("0755")).toBeInTheDocument();
    expect(screen.queryByText(/Decimal:/)).not.toBeInTheDocument();
  });

  it("triggers onChange with new mode when a matrix checkbox is toggled", async () => {
    const user = userEvent.setup();
    const handleChange = vi.fn();

    // Start with 420 (0644: rw-r--r--)
    renderWithProviders(
      <FileModeSelector value={420} onChange={handleChange} />,
    );

    // Click User Execute checkbox (User execute bit is +64 -> 420 + 64 = 484, or 0744)
    const userExecuteCheckbox = screen.getByLabelText("user execute");
    expect(userExecuteCheckbox).not.toBeChecked();

    await user.click(userExecuteCheckbox);
    expect(handleChange).toHaveBeenCalledWith(0o744); // 484
  });

  it("triggers onChange when a preset button is clicked", async () => {
    const user = userEvent.setup();
    const handleChange = vi.fn();

    renderWithProviders(
      <FileModeSelector value={undefined} onChange={handleChange} />,
    );

    const preset755 = screen.getByRole("button", { name: /755/i });
    await user.click(preset755);

    expect(handleChange).toHaveBeenCalledWith(0o755); // 493
  });

  it("triggers onChange when typing a valid octal value", async () => {
    const user = userEvent.setup();
    const handleChange = vi.fn();

    renderWithProviders(
      <FileModeSelector value={undefined} onChange={handleChange} />,
    );

    const input = screen.getByPlaceholderText("e.g. 0755");
    await user.type(input, "777");

    expect(handleChange).toHaveBeenLastCalledWith(511);
  });

  it("handles clearing the value", async () => {
    const user = userEvent.setup();
    const handleChange = vi.fn();

    renderWithProviders(
      <FileModeSelector value={511} onChange={handleChange} />,
    );

    const clearButton = screen.getByRole("button", { name: /clear/i });
    await user.click(clearButton);

    expect(handleChange).toHaveBeenCalledWith(undefined);
  });
});
