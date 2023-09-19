/*
  This file is part of Edgehog.

  Copyright 2022-2023 SECO Mind Srl

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

import { it, expect, vi } from "vitest";
import userEvent from "@testing-library/user-event";
import { screen } from "@testing-library/react";

import { renderWithProviders } from "setupTests";
import ConfirmModal from "./ConfirmModal";

it("renders correctly", () => {
  const props = {
    title: "Modal Title",
    confirmLabel: "OK",
    onConfirm: vi.fn(),
  };
  renderWithProviders(<ConfirmModal {...props}>Prompt message.</ConfirmModal>);
  const modal = document.querySelector("[role='dialog']");
  expect(modal).toBeInTheDocument();
  expect(modal).toHaveTextContent("Modal Title");
  expect(modal).toHaveTextContent("Prompt message.");
  expect(modal).toHaveTextContent("OK");
});

it("correctly confirms with the confirm button", () => {
  const props = {
    title: "Modal Title",
    confirmLabel: "OK",
    onConfirm: vi.fn(),
  };
  renderWithProviders(<ConfirmModal {...props}>Prompt message.</ConfirmModal>);
  userEvent.click(screen.getByText("OK"));
  expect(props.onConfirm).toHaveBeenCalledTimes(1);
});

it("correctly confirms by typing Enter", () => {
  const props = {
    title: "Modal Title",
    confirmLabel: "OK",
    onConfirm: vi.fn(),
  };
  renderWithProviders(<ConfirmModal {...props}>Prompt message.</ConfirmModal>);
  const title = screen.getByText(props.title);
  userEvent.type(title, "{enter}");
  expect(props.onConfirm).toHaveBeenCalledTimes(1);
});

it("correctly dimisses with the cancel button", () => {
  const props = {
    title: "Modal Title",
    confirmLabel: "OK",
    cancelLabel: "Cancel",
    onConfirm: vi.fn(),
    onCancel: vi.fn(),
  };
  renderWithProviders(<ConfirmModal {...props}>Prompt message.</ConfirmModal>);
  userEvent.click(screen.getByText("Cancel"));
  expect(props.onCancel).toHaveBeenCalledTimes(1);
  expect(props.onConfirm).not.toHaveBeenCalled();
});

it("correctly dimisses by typing Esc", () => {
  const props = {
    title: "Modal Title",
    confirmLabel: "OK",
    cancelLabel: "Cancel",
    onConfirm: vi.fn(),
    onCancel: vi.fn(),
  };
  renderWithProviders(<ConfirmModal {...props}>Prompt message.</ConfirmModal>);
  const modal = document.querySelector("[role='dialog']")!;
  userEvent.type(modal, "{esc}");
  expect(props.onCancel).toHaveBeenCalled();
  expect(props.onConfirm).not.toHaveBeenCalled();
});
