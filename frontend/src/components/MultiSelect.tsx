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

import Select, { components } from "react-select";
import type {
  MultiValue,
  ActionMeta,
  MultiValueGenericProps,
  MultiValueRemoveProps,
} from "react-select";
import CreatableSelect from "react-select/creatable";

import Icon from "components/Icon";
import Tag from "components/Tag";
import "./MultiSelect.scss";

const MultiValueContainer = <Option extends any>(
  props: MultiValueGenericProps<Option, true>
) => (
  <Tag className="me-1">
    <components.MultiValueContainer
      {...props}
      innerProps={{ className: "d-flex" }}
    />
  </Tag>
);

const MultiValueLabel = <Option extends any>(
  props: MultiValueGenericProps<Option, true>
) => (
  <components.MultiValueLabel {...props} innerProps={{ className: "me-1" }} />
);

const MultiValueRemove = <Option extends any>(
  props: MultiValueRemoveProps<Option, true>
) => {
  if (props.selectProps.isDisabled) {
    return null;
  }
  return (
    <components.MultiValueRemove {...props}>
      <Icon icon="close" />
    </components.MultiValueRemove>
  );
};

const customComponents = {
  MultiValueContainer,
  MultiValueLabel,
  MultiValueRemove,
};

type MultiSelectBaseProps<Option> = {
  disabled?: boolean;
  invalid?: boolean;
  loading?: boolean;
  value?: readonly Option[];
  options?: readonly Option[];
  onChange?: (
    value: MultiValue<Option>,
    actionMeta: ActionMeta<Option>
  ) => void;
  getOptionLabel?: (option: Option) => string;
  getOptionValue?: (option: Option) => string;
  isOptionDisabled?: (option: Option) => boolean;
  onBlur?: () => void;
};

type MultiSelectCreatableProps =
  | {
      creatable: true;
      isValidNewOption?: (value: string) => boolean;
      onCreateOption?: (value: string) => void;
    }
  | {
      creatable?: false;
      isValidNewOption?: never;
      onCreateOption?: never;
    };

type MultiSelectProps<Option> = MultiSelectBaseProps<Option> &
  MultiSelectCreatableProps;

const MultiSelect = <Option extends any>({
  creatable = false,
  disabled = false,
  invalid = false,
  loading = false,
  ...restProps
}: MultiSelectProps<Option>) => {
  const SelectComponent = creatable ? CreatableSelect : Select;

  return (
    <SelectComponent
      {...restProps}
      isMulti
      isDisabled={disabled}
      isLoading={loading}
      components={customComponents}
      className={`multi-select ${invalid ? "is-invalid" : ""}`}
      classNamePrefix="multi-select"
    />
  );
};

export default MultiSelect;
