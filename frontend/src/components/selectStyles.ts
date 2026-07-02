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

import { StylesConfig } from "react-select";

export const createSelectStyles = <Option>(
  invalid: boolean,
): StylesConfig<Option, boolean> => ({
  control: (base, state) => ({
    ...base,

    borderColor: invalid
      ? "var(--bs-danger)"
      : state.isFocused
        ? "rgba(var(--bs-primary-rgb), 0.5)"
        : base.borderColor,

    boxShadow: state.isFocused
      ? invalid
        ? "0 0 0 0.25rem rgba(var(--bs-danger-rgb), 0.25)"
        : "0 0 0 0.25rem rgba(var(--bs-primary-rgb), 0.25)"
      : base.boxShadow,

    "&:hover": {
      borderColor: invalid
        ? "var(--bs-danger)"
        : "rgba(var(--bs-primary-rgb), 0.5)",
    },
  }),
});
