// This file is part of Edgehog.
//
// Copyright 2026 SECO Mind Srl
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//    http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//
// SPDX-License-Identifier: Apache-2.0

import { Control, Controller, FieldValues, Path } from "react-hook-form";
import type { Props } from "react-select";

import type { Option } from "@/components/options/hooks";
import Select from "@/components/Select";
import { useMemo } from "react";

type ValueType = "primitive" | "object";

type SelectFormFieldProps<T extends FieldValues> = {
  control: Control<T>;
  name: Path<T>;
  options: readonly Option[];
  valueType?: ValueType;
  onChange?: (option: Option | null) => void;
} & Omit<
  Props<Option, false>,
  "value" | "onChange" | "options" | "name" | "isMulti"
>;

const SelectFormField = <T extends FieldValues>({
  control,
  name,
  options,
  valueType = "primitive",
  onChange,
  ...props
}: SelectFormFieldProps<T>) => {
  const optionsMap = useMemo(
    () => new Map(options.map((option) => [option.value, option])),
    [options],
  );

  const getValue = (fieldValue: { id: string } | string | null) => {
    if (!fieldValue) return null;

    const id = typeof fieldValue === "string" ? fieldValue : fieldValue.id;

    return optionsMap.get(id) ?? null;
  };
  const formatValue = (option: Option | null) => {
    if (!option) return null;

    return valueType === "object"
      ? { id: option.value, name: option.label }
      : option.value;
  };

  return (
    <Controller
      control={control}
      name={name}
      render={({ field, fieldState }) => (
        <Select
          {...props}
          value={getValue(field.value)}
          options={options}
          invalid={fieldState.invalid}
          onBlur={field.onBlur}
          onChange={(option) => {
            field.onChange(formatValue(option));
            onChange?.(option);
          }}
        />
      )}
    />
  );
};

export default SelectFormField;
