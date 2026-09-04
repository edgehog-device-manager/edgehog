/*
 * This file is part of Edgehog.
 *
 * Copyright 2026 SECO Mind Srl
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

import { it, expect, afterEach, vi } from "vitest";
import userEvent from "@testing-library/user-event";
import { screen } from "@testing-library/react";

import { renderWithProviders } from "@/setupTests";
import MonacoEditor from "./MonacoEditor";

const { editorProps } = vi.hoisted(() => ({
  editorProps: {
    current: undefined as
      | (Record<string, unknown> & { options?: Record<string, unknown> })
      | undefined,
  },
}));

vi.mock("@monaco-editor/react", () => ({
  Editor: (props: Record<string, unknown>) => {
    editorProps.current = props;

    return null;
  },
}));

const STORAGE_KEY = "editor-preferences";

afterEach(() => {
  localStorage.removeItem(STORAGE_KEY);
});

it("toggles vim mode and persists the preference", async () => {
  const user = userEvent.setup();

  renderWithProviders(<MonacoEditor value="" language="yaml" />);

  const vimToggle = screen.getByTitle("Toggle Vim mode");

  expect(screen.queryByTestId("vim-status-bar")).not.toBeInTheDocument();

  await user.click(vimToggle);

  expect(screen.getByTestId("vim-status-bar")).toBeInTheDocument();
  expect(JSON.parse(localStorage.getItem(STORAGE_KEY)!).vimEnabled).toBe(true);
  expect(vimToggle.getAttribute("aria-pressed")).toBe("true");

  await user.click(vimToggle);

  expect(screen.queryByTestId("vim-status-bar")).not.toBeInTheDocument();
  expect(JSON.parse(localStorage.getItem(STORAGE_KEY)!).vimEnabled).toBe(false);
});

it("changes the font size through the zoom controls", async () => {
  const user = userEvent.setup();

  renderWithProviders(<MonacoEditor value="" language="yaml" />);

  await user.click(screen.getByTitle("Increase font size"));

  expect(JSON.parse(localStorage.getItem(STORAGE_KEY)!).fontSize).toBe(16);

  await user.click(screen.getByTitle("Decrease font size"));

  expect(JSON.parse(localStorage.getItem(STORAGE_KEY)!).fontSize).toBe(14);

  await user.click(screen.getByTitle("Reset font size"));

  expect(JSON.parse(localStorage.getItem(STORAGE_KEY)!).fontSize).toBe(14);
});

it("restores a stored vim preference on mount", () => {
  localStorage.setItem(STORAGE_KEY, JSON.stringify({ vimEnabled: true }));

  renderWithProviders(<MonacoEditor value="" language="yaml" />);

  expect(screen.getByTestId("vim-status-bar")).toBeInTheDocument();
});

it("renders the editor text with the app monospace stack", () => {
  renderWithProviders(<MonacoEditor value="" language="yaml" />);

  expect(editorProps.current?.options).toMatchObject({
    fontFamily: "var(--bs-font-monospace, monospace)",
  });
  expect(editorProps.current?.className).toBeUndefined();
});
