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
import Select from "react-select";

import type { Option } from "@/components/options/hooks";

type SelectFormFieldProps<T extends FieldValues> = {
  control: Control<T>;
  name: Path<T>;
  options: Option[];
  isClearable?: boolean;
  excludedIds?: string[];
};

const SelectFormField = <T extends FieldValues>({
  control,
  name,
  options,
  isClearable = true,
  excludedIds = [],
}: SelectFormFieldProps<T>) => {
  const availableOptions = options.filter(
    (o) => !excludedIds.includes(o.value),
  );
  return (
    <Controller
      control={control}
      name={name}
      render={({ field, fieldState }) => {
        const selected = options.find((o) => o.value === field.value) ?? null;

        return (
          <Select
            className={fieldState.invalid ? "is-invalid" : ""}
            value={selected}
            options={availableOptions}
            isClearable={isClearable}
            onChange={(option) => field.onChange(option?.value ?? null)}
            onBlur={field.onBlur}
          />
        );
      }}
    />
  );
};

export default SelectFormField;
