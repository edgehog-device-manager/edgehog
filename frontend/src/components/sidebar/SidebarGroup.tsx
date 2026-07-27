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

import React, { useState } from "react";
import Accordion from "react-bootstrap/Accordion";
import Dropdown from "react-bootstrap/Dropdown";
import { useLocation } from "react-router-dom";

import Icon from "@/components/Icon";
import { matchPaths } from "@/Navigation";
import { type SidebarItemProps } from "@/components/sidebar/SidebarItem";

type SidebarGroupProps = {
  children: React.ReactNode;
  icon: React.ComponentProps<typeof Icon>["icon"];
  label: React.ReactNode;
  eventKey: string;
  isCollapsed?: boolean;
};

const SidebarGroup = ({
  children,
  icon,
  label,
  eventKey,
  isCollapsed,
}: SidebarGroupProps) => {
  const location = useLocation();
  const [isOpen, setIsOpen] = useState(false);

  const isActive = React.Children.toArray(children).some((child) => {
    if (React.isValidElement(child)) {
      const props = child.props as SidebarItemProps;
      const routes = props.activeRoutes || props.route;
      return routes ? matchPaths(routes, location.pathname) : false;
    }
    return false;
  });

  const handleMenuClick = () => setIsOpen(false);

  if (isCollapsed) {
    return (
      <Dropdown
        show={isOpen}
        onToggle={setIsOpen}
        className="sidebar-group-dropdown"
      >
        <Dropdown.Toggle
          as="div"
          className={`sidebar-link d-flex align-items-center mx-2 px-3 py-2 rounded fw-medium ${
            isActive ? "active bg-primary text-light" : "text-dark"
          }`}
        >
          <Icon icon={icon} />
        </Dropdown.Toggle>

        <Dropdown.Menu
          renderOnMount
          popperConfig={{ strategy: "fixed" }}
          className="sidebar-dropdown-menu border-0 ms-2 px-2 py-3 shadow-lg"
        >
          <div className="dropdown-header px-3 pt-1 fw-bold text-uppercase font-black">
            {label}
          </div>
          <div className="d-flex flex-column">
            {React.Children.map(children, (child) => {
              if (React.isValidElement(child)) {
                return React.cloneElement(child as React.ReactElement<any>, {
                  onClick: () => {
                    if (child.props.onClick) child.props.onClick();
                    handleMenuClick();
                  },
                });
              }
              return child;
            })}
          </div>
        </Dropdown.Menu>
      </Dropdown>
    );
  }

  return (
    <Accordion defaultActiveKey={eventKey} alwaysOpen className="w-100">
      <Accordion.Item eventKey={eventKey} className="border-0">
        <Accordion.Header className="m-2">
          <div className="d-flex align-items-center w-100 py-2 rounded text-dark fw-bold">
            <span className="sidebar-text text-truncate ms-3">{label}</span>
            <Icon icon="caretDown" className="sidebar-caret me-1 ms-auto" />
          </div>
        </Accordion.Header>
        <Accordion.Body className="sidebar-group-children p-0">
          <div className="d-flex flex-column">{children}</div>
        </Accordion.Body>
      </Accordion.Item>
    </Accordion>
  );
};

export type { SidebarGroupProps };

export default SidebarGroup;
