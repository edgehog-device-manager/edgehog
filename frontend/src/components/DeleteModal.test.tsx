/*
 * This file is part of Edgehog.
 *
 * Copyright 2022-2026 SECO Mind Srl
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

import { it, expect, vi } from "vitest";
import userEvent from "@testing-library/user-event";
import { screen } from "@testing-library/react";

import { renderWithProviders } from "@/setupTests";
import DeleteModal from "./DeleteModal";

it("renders correctly", () => {
  const props = {
    title: "Modal Title",
    confirmText: "confirm-text",
    onCancel: vi.fn(),
    onConfirm: vi.fn(),
  };
  renderWithProviders(<DeleteModal {...props}>Prompt message.</DeleteModal>);
  const modal = screen.getByRole("dialog");
  expect(modal).toBeVisible();
  expect(modal).toHaveTextContent("Modal Title");
  expect(modal).toHaveTextContent("Prompt message.");
  expect(modal).toHaveTextContent("Please type confirm-text to confirm.");
  expect(modal).toHaveTextContent("Delete");
});

it("cannot confirm without entering the confirm text", async () => {
  const props = {
    title: "Modal Title",
    confirmText: "confirm-text",
    onCancel: vi.fn(),
    onConfirm: vi.fn(),
  };
  renderWithProviders(<DeleteModal {...props}>Prompt message.</DeleteModal>);

  await userEvent.click(screen.getByText("Delete"));
  const title = screen.getByText(props.title);
  await userEvent.type(title, "{Enter}");
  expect(props.onConfirm).not.toHaveBeenCalled();

  await userEvent.type(screen.getByRole("textbox"), "confirm-text");

  await userEvent.click(screen.getByText("Delete"));
  expect(props.onConfirm).toHaveBeenCalledTimes(1);
  await userEvent.type(title, "{Enter}");
  expect(props.onConfirm).toHaveBeenCalledTimes(2);
});

it("does not confirm by dismissing", async () => {
  const props = {
    title: "Modal Title",
    confirmText: "confirm-text",
    onCancel: vi.fn(),
    onConfirm: vi.fn(),
  };
  renderWithProviders(<DeleteModal {...props}>Prompt message.</DeleteModal>);

  await userEvent.click(screen.getByText("Cancel"));
  const modal = screen.getByRole("dialog");
  await userEvent.type(modal, "{Escape}");
  expect(props.onConfirm).not.toHaveBeenCalled();
  expect(props.onCancel).toHaveBeenCalled();
});
