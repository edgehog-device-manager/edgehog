/*
  This file is part of Edgehog.

  Copyright 2022 SECO Mind Srl

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

import userEvent from "@testing-library/user-event";
import { screen } from "@testing-library/react";

import { renderWithProviders } from "setupTests";
import DeleteModal from "./DeleteModal";

it("renders correctly", () => {
  const props = {
    title: "Modal Title",
    confirmText: "confirm-text",
    onCancel: jest.fn(),
    onConfirm: jest.fn(),
  };
  renderWithProviders(<DeleteModal {...props}>Prompt message.</DeleteModal>);
  const modal = document.querySelector("[role='dialog']");
  expect(modal).toBeInTheDocument();
  expect(modal).toHaveTextContent("Modal Title");
  expect(modal).toHaveTextContent("Prompt message.");
  expect(modal).toHaveTextContent("Please type confirm-text to confirm.");
  expect(modal).toHaveTextContent("Delete");
});

it("cannot confirm without entering the confirm text", () => {
  const props = {
    title: "Modal Title",
    confirmText: "confirm-text",
    onCancel: jest.fn(),
    onConfirm: jest.fn(),
  };
  renderWithProviders(<DeleteModal {...props}>Prompt message.</DeleteModal>);

  userEvent.click(screen.getByText("Delete"));
  const title = screen.getByText(props.title);
  userEvent.type(title, "{enter}");
  expect(props.onConfirm).not.toHaveBeenCalled();

  userEvent.type(screen.getByRole("textbox"), "confirm-text");

  userEvent.click(screen.getByText("Delete"));
  expect(props.onConfirm).toHaveBeenCalledTimes(1);
  userEvent.type(title, "{enter}");
  expect(props.onConfirm).toHaveBeenCalledTimes(2);
});

it("does not confirm by dismissing", () => {
  const props = {
    title: "Modal Title",
    confirmText: "confirm-text",
    onCancel: jest.fn(),
    onConfirm: jest.fn(),
  };
  renderWithProviders(<DeleteModal {...props}>Prompt message.</DeleteModal>);

  userEvent.click(screen.getByText("Cancel"));
  const modal = document.querySelector("[role='dialog']")!;
  userEvent.type(modal, "{esc}");
  expect(props.onConfirm).not.toHaveBeenCalled();
  expect(props.onCancel).toHaveBeenCalled();
});
