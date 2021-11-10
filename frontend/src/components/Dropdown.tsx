/*
  This file is part of Edgehog.

  Copyright 2021 SECO Mind Srl

  Licensed under the Apache License, Version 2.0 (the "License");
  you may not use this file except in compliance with the License.
  You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

  Unless required by applicable law or agreed to in writing, software
  distributed under the License is distributed on an "AS IS" BASIS,
  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
  See the License for the specific language governing permissions and
  limitations under the License.
*/

import React from "react";
import BoostrapDropdown from "react-bootstrap/Dropdown";

import "./Dropdown.scss";

interface Props {
  align?: "end" | "start";
  children?: React.ReactNode;
  className?: string;
  toggle: React.ReactNode;
}

const Dropdown = ({
  align = "start",
  children,
  className = "",
  toggle,
}: Props) => (
  <BoostrapDropdown align={align} className={`Dropdown ${className}`}>
    <BoostrapDropdown.Toggle as="div">{toggle}</BoostrapDropdown.Toggle>
    <BoostrapDropdown.Menu className="shadow border-end-0 border-bottom-0 border-start-0 border-primary rounded-0">
      {children}
    </BoostrapDropdown.Menu>
  </BoostrapDropdown>
);

Dropdown.Divider = BoostrapDropdown.Divider;
Dropdown.Item = BoostrapDropdown.Item;

export default Dropdown;
