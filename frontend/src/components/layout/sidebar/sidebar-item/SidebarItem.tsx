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

import NavLink from "react-bootstrap/NavLink";
import { useLocation } from "react-router-dom";

import { Link, ParametricRoute } from "@/Navigation";
import { matchPaths, Route } from "@/Navigation";
import Icon from "@/components/ui/icon/Icon";

type SidebarItemProps = {
  icon?: React.ComponentProps<typeof Icon>["icon"];
  label: JSX.Element;
  activeRoutes?: Route | Route[];
  className?: string;
} & ParametricRoute;

const SidebarItem = ({
  icon,
  label,
  activeRoutes,
  className = "",
  ...linkProps
}: SidebarItemProps) => {
  const location = useLocation();
  const matchingRoutes = activeRoutes || linkProps.route;
  const isActive = matchPaths(matchingRoutes, location.pathname);
  const look = isActive ? "active bg-primary text-light" : "text-dark";
  const finalClassName =
    `sidebar-link d-flex align-items-center mx-2 px-3 py-2 rounded fw-medium ${look} ${className}`.trim();

  return (
    <NavLink as={Link} className={finalClassName} {...linkProps}>
      {icon && <Icon icon={icon} className="sidebar-icon flex-shrink-0" />}
      <span className="sidebar-text sidebar-item-label text-truncate">
        {label}
      </span>
    </NavLink>
  );
};

export type { SidebarItemProps };

export default SidebarItem;
