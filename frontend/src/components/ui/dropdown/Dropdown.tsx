/*
  This file is part of Edgehog.

  Copyright 2021-2026 SECO Mind Srl

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

import React from "react";
import BootstrapDropdown from "react-bootstrap/Dropdown";
import type { DropdownProps as BootstrapDropdownProps } from "react-bootstrap/Dropdown";

import "./Dropdown.scss";

export type DropdownProps = BootstrapDropdownProps & {
  toggle?: React.ReactNode;
};

const Dropdown = ({
  align = "start",
  children,
  className = "",
  toggle,
  ...restProps
}: DropdownProps) => {
  if (toggle) {
    return (
      <BootstrapDropdown align={align} className={`Dropdown ${className}`} {...restProps}>
        <BootstrapDropdown.Toggle as="div">{toggle}</BootstrapDropdown.Toggle>
        <BootstrapDropdown.Menu className="shadow border-end-0 border-bottom-0 border-start-0 border-primary rounded-0">
          {children}
        </BootstrapDropdown.Menu>
      </BootstrapDropdown>
    );
  }

  return (
    <BootstrapDropdown align={align} className={className} {...restProps}>
      {children}
    </BootstrapDropdown>
  );
};

Dropdown.Toggle = BootstrapDropdown.Toggle;
Dropdown.Menu = BootstrapDropdown.Menu;
Dropdown.Divider = BootstrapDropdown.Divider;
Dropdown.Item = BootstrapDropdown.Item;
Dropdown.Header = BootstrapDropdown.Header;
Dropdown.ItemText = BootstrapDropdown.ItemText;

export default Dropdown;
