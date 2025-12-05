/*
 * This file is part of Edgehog.
 *
 * Copyright 2021, 2025 SECO Mind Srl
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

import React, { useCallback } from "react";
import { useIntl } from "react-intl";
import Form from "react-bootstrap/Form";
import InputGroup from "react-bootstrap/InputGroup";

import Icon from "@/components/Icon";

interface Props {
  className?: string;
  onChange?: (searchText: string) => void;
}

const SearchBox = ({ className = "", onChange }: Props) => {
  const intl = useIntl();

  const handleChange: React.ChangeEventHandler<HTMLInputElement> = useCallback(
    (event) => {
      const searchText = event.target.value;
      onChange && onChange(searchText);
    },
    [onChange],
  );

  return (
    <Form className={`justify-content-end ${className}`}>
      <InputGroup>
        <Form.Control
          className="border-end-0"
          type="search"
          placeholder={intl.formatMessage({
            id: "components.SearchBox.searchPlaceholder",
            defaultMessage: "Search",
            description: "Placeholder for the search input of the SearchBox",
          })}
          onChange={handleChange}
        />
        <InputGroup.Text className="bg-transparent">
          <Icon icon="search" />
        </InputGroup.Text>
      </InputGroup>
    </Form>
  );
};

export default SearchBox;
