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

import {
  components,
  GroupBase,
  MultiValueGenericProps,
  MultiValueRemoveProps,
} from "react-select";
import CreatableSelect, { CreatableProps } from "react-select/creatable";

import Icon from "components/Icon";
import Tag from "components/Tag";

type Option = {
  label: string;
  value: string;
};

type MultiComponentProps = MultiValueGenericProps<Option, true>;

const MultiValueContainer = (props: MultiComponentProps) => {
  const { children, data, selectProps } = props;
  return (
    <Tag className="me-1">
      <components.MultiValueContainer
        data={data}
        innerProps={{ className: "d-flex" }}
        selectProps={selectProps}
      >
        {children}
      </components.MultiValueContainer>
    </Tag>
  );
};

const MultiValueLabel = (props: MultiComponentProps) => {
  const { data, selectProps } = props;
  return (
    <components.MultiValueLabel
      data={data}
      innerProps={{ className: "me-1" }}
      selectProps={selectProps}
    >
      {data.label}
    </components.MultiValueLabel>
  );
};

const MultiValueRemove = (props: MultiValueRemoveProps<Option, true>) => {
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

const getOptionLabel = (option: Option) => option.label;
const getOptionValue = (option: Option) => option.value;

type MSProps = {
  disabled?: boolean;
  loading?: boolean;
};
type MultiSelectProps = Omit<
  CreatableProps<Option, true, GroupBase<Option>>,
  | "isMulti"
  | "isDisabled"
  | "isLoading"
  | "components"
  | "getOptionLabel"
  | "getOptionValue"
> &
  MSProps;

const MultiSelect = ({
  disabled = false,
  loading = false,
  ...restProps
}: MultiSelectProps) => {
  return (
    <CreatableSelect
      {...restProps}
      isMulti
      isDisabled={disabled}
      isLoading={loading}
      components={customComponents}
      getOptionLabel={getOptionLabel}
      getOptionValue={getOptionValue}
    />
  );
};

export default MultiSelect;
