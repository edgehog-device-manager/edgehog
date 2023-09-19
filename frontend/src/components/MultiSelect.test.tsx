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
import { render, fireEvent } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import selectEvent from "react-select-event";

import MultiSelect from "./MultiSelect";

type Option = { value: string; label: string; [key: string]: unknown };

const options: Option[] = [
  { value: "1", label: "Option 1" },
  { value: "2", label: "Option 2" },
  { value: "3", label: "Option 3" },
];

const customOption: Option = {
  value: "custom",
  label: "custom",
  __isNew__: true,
};

it("correctly selects an option", async () => {
  const onChange = vi.fn();
  const props = {
    options,
    onChange,
  };
  const { getByRole } = render(<MultiSelect {...props} />);

  await selectEvent.select(getByRole("combobox"), options[0].label);
  expect(onChange).toHaveBeenCalledTimes(1);
  expect(onChange).toHaveBeenLastCalledWith(
    options.slice(0, 1),
    expect.anything()
  );
});

it("correctly adds an option to selected", async () => {
  const onChange = vi.fn();
  const props = {
    options,
    value: options.slice(0, 1),
    onChange,
  };
  const { getByRole } = render(<MultiSelect {...props} />);

  await selectEvent.select(getByRole("combobox"), options[1].label);
  expect(onChange).toHaveBeenCalledTimes(1);
  expect(onChange).toHaveBeenLastCalledWith(
    options.slice(0, 2),
    expect.anything()
  );
});

it("correctly clears selected options", async () => {
  const onChange = vi.fn();
  const props = {
    options,
    value: options,
    onChange,
  };
  const { getByRole } = render(<MultiSelect {...props} />);

  await selectEvent.clearAll(getByRole("combobox"));
  expect(onChange).toHaveBeenCalledTimes(1);
  expect(onChange).toHaveBeenLastCalledWith([], expect.anything());
});

it("correctly creates new option", async () => {
  const onChange = vi.fn();
  const props = {
    creatable: true,
    options,
    onChange,
  };
  const { getByRole } = render(<MultiSelect {...props} />);
  const input = getByRole("combobox");
  fireEvent.change(input, { target: { value: customOption.value } });
  fireEvent.keyDown(input, { key: "Enter", code: "Enter", charCode: 13 });

  expect(onChange).toHaveBeenCalledTimes(1);
  expect(onChange).toHaveBeenLastCalledWith([customOption], expect.anything());
});

it("correctly creates new option adding to selected", async () => {
  const onChange = vi.fn();
  const props = {
    creatable: true,
    options,
    value: options,
    onChange,
  };
  const { getByRole } = render(<MultiSelect {...props} />);
  const input = getByRole("combobox");
  fireEvent.change(input, { target: { value: customOption.value } });
  fireEvent.keyDown(input, { key: "Enter", code: "Enter", charCode: 13 });

  expect(onChange).toHaveBeenCalledTimes(1);
  expect(onChange).toHaveBeenLastCalledWith(
    options.concat([customOption]),
    expect.anything()
  );
});

it("correctly call onBlur", async () => {
  const onBlur = vi.fn();
  const props = {
    options,
    onBlur,
  };
  const { getByRole } = render(<MultiSelect {...props} />);
  const input = getByRole("combobox");
  input.focus();
  expect(input).toHaveFocus();

  await userEvent.tab();
  expect(input).not.toHaveFocus();
  expect(onBlur).toHaveBeenCalledTimes(1);
});
