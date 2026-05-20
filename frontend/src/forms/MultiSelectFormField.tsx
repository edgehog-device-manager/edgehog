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

import MultiSelect from "@/components/MultiSelect";
import type { Option } from "@/components/options/hooks";

type MultiSelectValue = {
  id: string;
};

type GenericMultiSelectProps<T extends FieldValues> = {
  control: Control<T>;
  name: Path<T>;
  options: Option[];
};

const MultiSelectFormField = <T extends FieldValues>({
  control,
  name,
  options,
}: GenericMultiSelectProps<T>) => {
  return (
    <Controller
      name={name}
      control={control}
      render={({ field, fieldState }) => {
        const value = (field.value ?? []) as MultiSelectValue[];

        const mappedValue = value.map((v) => {
          const found = options.find((o) => o.value === v.id);

          return (
            found ?? {
              value: v.id,
              label: v.id,
            }
          );
        });

        return (
          <MultiSelect
            invalid={fieldState.invalid}
            value={mappedValue}
            options={options}
            onBlur={field.onBlur}
            onChange={(selected) => {
              field.onChange(
                selected.map((s) => ({
                  id: s.value,
                })),
              );
            }}
            getOptionValue={(o) => o.value}
            getOptionLabel={(o) => o.label}
          />
        );
      }}
    />
  );
};

export default MultiSelectFormField;
