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

import ReactSelect, { Props } from "react-select";

import { createSelectStyles } from "./selectStyles";

type SelectProps<Option> = Omit<Props<Option, false>, "isMulti"> & {
  invalid?: boolean;
  loading?: boolean;
  disabled?: boolean;
};

const Select = <Option,>({
  invalid = false,
  loading = false,
  disabled = false,
  styles,
  className,
  ...props
}: SelectProps<Option>) => {
  return (
    <ReactSelect
      {...props}
      isLoading={loading}
      isDisabled={disabled}
      className={`${className ?? ""} ${invalid ? "is-invalid" : ""}`.trim()}
      styles={{
        ...createSelectStyles<Option>(invalid),
        ...styles,
      }}
    />
  );
};

export default Select;
