/*
  This file is part of Edgehog.

  Copyright 2021-2023 SECO Mind Srl

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

import React, { useCallback, useState } from "react";
import { useLocation } from "react-router-dom";
import { FormattedMessage } from "react-intl";
import Accordion from "react-bootstrap/Accordion";
import Navbar from "react-bootstrap/Navbar";
import Nav from "react-bootstrap/Nav";
import NavLink from "react-bootstrap/NavLink";

import Icon from "components/Icon";
import { Link, matchPaths, ParametricRoute, Route } from "Navigation";
import "./Sidebar.scss";

type SidebarItemProps = {
  icon?: React.ComponentProps<typeof Icon>["icon"];
  label: JSX.Element;
  activeRoutes?: Route | Route[];
} & ParametricRoute;

const SidebarItem = ({
  icon,
  label,
  activeRoutes,
  ...linkProps
}: SidebarItemProps) => {
  const location = useLocation();
  const matchingRoutes = activeRoutes ? activeRoutes : linkProps.route;
  const isActive = matchPaths(matchingRoutes, location.pathname);
  return (
    <NavLink
      as={Link}
      className={`px-3 py-2 w-100 d-flex align-items-center ${
        isActive ? "text-light bg-primary" : "text-dark"
      }`}
      {...linkProps}
    >
      {icon && <Icon icon={icon} className="ms-1 me-2" />}
      <span className={icon ? "" : "ms-1 ps-4"}>{label}</span>
    </NavLink>
  );
};

interface SidebarItemGroupProps {
  children: React.ReactNode;
  icon: React.ComponentProps<typeof Icon>["icon"];
  label: React.ReactNode;
}

const SidebarItemGroup = ({ children, icon, label }: SidebarItemGroupProps) => {
  const [isOpen, setIsOpen] = useState(true);
  const toggleIsOpen = useCallback(() => setIsOpen((o) => !o), []);
  return (
    <Accordion className="w-100">
      <Accordion.Button
        as={Nav.Link}
        eventKey="sidebar-item"
        onClick={toggleIsOpen}
        className="text-dark bg-white shadow-sm"
      >
        <div className="w-100 d-flex align-items-center">
          <Icon icon={icon} className="me-2" />
          {label}
          <Icon icon={isOpen ? "caretUp" : "caretDown"} className="ms-auto" />
        </div>
      </Accordion.Button>
      <Accordion.Collapse eventKey="sidebar-item" in={isOpen}>
        <>{children}</>
      </Accordion.Collapse>
    </Accordion>
  );
};

const Sidebar = () => (
  <Navbar bg="light" className="sidebar-menu flex-column p-0 shadow">
    <SidebarItem
      label={
        <FormattedMessage
          id="components.Sidebar.devicesLabel"
          defaultMessage="Devices"
        />
      }
      icon="devices"
      route={Route.devices}
      activeRoutes={[Route.devices, Route.devicesEdit]}
    />
    <SidebarItem
      label={
        <FormattedMessage
          id="components.Sidebar.deviceGroupsLabel"
          defaultMessage="Groups"
        />
      }
      icon="deviceGroups"
      route={Route.deviceGroups}
      activeRoutes={[
        Route.deviceGroups,
        Route.deviceGroupsEdit,
        Route.deviceGroupsNew,
      ]}
    />
    <SidebarItemGroup
      label={
        <FormattedMessage
          id="components.Sidebar.otaUpdatesGroupLabel"
          defaultMessage="OTA Updates"
        />
      }
      icon="otaUpdates"
    >
      <SidebarItem
        label={
          <FormattedMessage
            id="components.Sidebar.updateCampaignsLabel"
            defaultMessage="Update Campaigns"
          />
        }
        route={Route.updateCampaigns}
        activeRoutes={[Route.updateCampaigns, Route.updateCampaignsEdit]}
      />
      <SidebarItem
        label={
          <FormattedMessage
            id="components.Sidebar.updateChannelsLabel"
            defaultMessage="Update Channels"
          />
        }
        route={Route.updateChannels}
        activeRoutes={[
          Route.updateChannels,
          Route.updateChannelsEdit,
          Route.updateChannelsNew,
        ]}
      />
      <SidebarItem
        label={
          <FormattedMessage
            id="components.Sidebar.baseImageCollectionsLabel"
            defaultMessage="Base Image Collections"
          />
        }
        route={Route.baseImageCollections}
        activeRoutes={[
          Route.baseImageCollections,
          Route.baseImageCollectionsNew,
          Route.baseImageCollectionsEdit,
          Route.baseImagesNew,
          Route.baseImagesEdit,
        ]}
      />
    </SidebarItemGroup>
    <SidebarItemGroup
      label={
        <FormattedMessage
          id="components.Sidebar.modelsGroupLabel"
          defaultMessage="Models"
        />
      }
      icon="models"
    >
      <SidebarItem
        label={
          <FormattedMessage
            id="components.Sidebar.modelsLabel"
            defaultMessage="System Models"
          />
        }
        route={Route.systemModels}
        activeRoutes={[
          Route.systemModels,
          Route.systemModelsNew,
          Route.systemModelsEdit,
        ]}
      />
      <SidebarItem
        label={
          <FormattedMessage
            id="components.Sidebar.hardwareTypesLabel"
            defaultMessage="Hardware Types"
          />
        }
        route={Route.hardwareTypes}
        activeRoutes={[
          Route.hardwareTypes,
          Route.hardwareTypesNew,
          Route.hardwareTypesEdit,
        ]}
      />
    </SidebarItemGroup>
    <SidebarItemGroup
      label={
        <FormattedMessage
          id="components.Sidebar.applicationsLabel"
          defaultMessage="Applications"
        />
      }
      icon="applications"
    >
      <SidebarItem
        label={
          <FormattedMessage
            id="components.Sidebar.applications.applicationsLabel"
            defaultMessage="Applications"
          />
        }
        route={Route.applications}
        activeRoutes={[
          Route.applications,
          Route.applicationNew,
          Route.application,
          Route.release,
        ]}
      />
    </SidebarItemGroup>
  </Navbar>
);

export default Sidebar;
