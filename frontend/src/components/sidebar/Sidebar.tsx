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

import "@/components/sidebar/Sidebar.scss";
import { Route } from "@/Navigation";
import SidebarHeader from "@/components/sidebar/SidebarHeader";
import SidebarItem from "@/components/sidebar/SidebarItem";
import FleetSidebarGroup from "@/components/sidebar/groups/FleetSidebarGroup";
import FilesSidebarGroup from "@/components/sidebar/groups/FilesSidebarGroup";
import OtaSidebarGroup from "@/components/sidebar/groups/OtaSidebarGroup";
import AppsSidebarGroup from "@/components/sidebar/groups/AppsSidebarGroup";
import SidebarFooter from "@/components/sidebar/SidebarFooter";

type SidebarProps = {
  appName?: string;
  appVersion: string;
  repoUrl?: string;
  docsUrl?: string;
  isDesktopCollapsed: boolean;
  isMobileMenuOpen: boolean;
  onToggleCollapse: () => void;
};

const Sidebar = ({
  appName,
  appVersion,
  repoUrl,
  docsUrl,
  isDesktopCollapsed,
  isMobileMenuOpen,
  onToggleCollapse,
}: SidebarProps) => {
  const collapsed = isDesktopCollapsed ? " collapsed-desktop" : "";
  const mobile = isMobileMenuOpen ? " mobile-open" : "";

  return (
    <aside
      className={`custom-sidebar d-flex flex-column h-100 position-relative shadow${collapsed}${mobile}`}
    >
      <SidebarHeader
        isDesktopCollapsed={isDesktopCollapsed}
        isMobileMenuOpen={isMobileMenuOpen}
        onToggleCollapse={onToggleCollapse}
      />
      <nav className="custom-scrollbar d-flex flex-column flex-grow-1 gap-1 overflow-auto py-2">
        <SidebarItem
          label={
            <FormattedMessage
              id="components.sidebar.Sidebar.devicesLabel"
              defaultMessage="Devices"
            />
          }
          icon="devices"
          route={Route.devices}
          activeRoutes={[
            Route.devices,
            Route.devicesEdit,
            Route.deploymentEdit,
          ]}
        />

        <FleetSidebarGroup collapsed={isDesktopCollapsed} />
        <FilesSidebarGroup collapsed={isDesktopCollapsed} />
        <OtaSidebarGroup collapsed={isDesktopCollapsed} />
        <AppsSidebarGroup collapsed={isDesktopCollapsed} />
      </nav>
      <SidebarFooter
        appName={appName}
        appVersion={appVersion}
        repoUrl={repoUrl}
        docsUrl={docsUrl}
      />
    </aside>
  );
};

export default Sidebar;
