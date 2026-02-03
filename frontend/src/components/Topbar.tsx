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

import { FormattedMessage } from "react-intl";
import Navbar from "react-bootstrap/Navbar";

import assets from "@/assets";
import Dropdown from "@/components/Dropdown";
import Icon from "@/components/Icon";
import { Link, Route } from "@/Navigation";
import "./Topbar.scss";

interface UserMenuProps {
  className?: string;
}

const UserMenu = ({ className }: UserMenuProps) => {
  return (
    <Dropdown
      align="end"
      className={className}
      toggle={
        <div className="btn">
          <Icon icon="profile" className="me-2" />
          <Icon icon="caretDown" />
        </div>
      }
    >
      <Dropdown.Item as={Link} route={Route.logout}>
        <FormattedMessage
          id="components.Topbar.userMenu.logoutLabel"
          defaultMessage="Logout"
        />
      </Dropdown.Item>
    </Dropdown>
  );
};

const Topbar = () => {
  return (
    <div className="pb-3">
      <Navbar className="Topbar navbar navbar-light shadow">
        <Navbar.Brand className="h-100 px-4">
          <img alt="Logo" src={assets.images.brand} className="h-100" />
        </Navbar.Brand>
        <UserMenu className="ms-auto pe-2" />
      </Navbar>
    </div>
  );
};

export default Topbar;
