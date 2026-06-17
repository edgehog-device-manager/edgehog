/*
 * This file is part of Edgehog.
 *
 * Copyright 2021-2026 SECO Mind Srl
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

import React, { useCallback, useId } from "react";
import Form from "react-bootstrap/Form";
import InputGroup from "react-bootstrap/InputGroup";
import { useIntl } from "react-intl";

import Icon from "@/components/Icon";
import "@/components/SearchBox.scss";

interface Props {
  className?: string;
  onChange?: (searchText: string) => void;
  value?: string;
}

const SearchBox = ({ className = "", onChange, value }: Props) => {
  const intl = useIntl();
  const searchInputId = useId();

  const handleChange: React.ChangeEventHandler<HTMLInputElement> = useCallback(
    (event) => {
      const searchText = event.target.value;
      if (onChange) {
        onChange(searchText);
      }
    },
    [onChange],
  );

  return (
    <Form className={`w-100 ${className}`}>
      <InputGroup className="custom-search-group">
        <InputGroup.Text
          as="label"
          htmlFor={searchInputId}
          className="search-icon-addon px-3"
        >
          <Icon icon="search" />
        </InputGroup.Text>
        <Form.Control
          id={searchInputId}
          className="search-input"
          type="search"
          placeholder={intl.formatMessage({
            id: "components.SearchBox.searchPlaceholder",
            defaultMessage: "Search...",
            description: "Placeholder for the search input of the SearchBox",
          })}
          value={value}
          onChange={handleChange}
        />
      </InputGroup>
    </Form>
  );
};

export default SearchBox;
