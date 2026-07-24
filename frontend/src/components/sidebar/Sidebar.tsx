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

import React, { useState } from "react";
import Accordion from "react-bootstrap/Accordion";
import Button from "react-bootstrap/Button";
import Dropdown from "react-bootstrap/Dropdown";
import Image from "react-bootstrap/Image";
import NavLink from "react-bootstrap/NavLink";
import { FormattedMessage } from "react-intl";
import { useLocation } from "react-router-dom";

import assets from "@/assets";
import Icon from "@/components/Icon";
import "@/components/Sidebar.scss";
import { Link, matchPaths, ParametricRoute, Route } from "@/Navigation";

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

  return (
    <NavLink
      as={Link}
      className={`sidebar-link d-flex align-items-center mx-2 px-3 py-2 rounded fw-medium ${
        isActive ? "active bg-primary text-light" : "text-dark"
      } ${className}`.trim()}
      {...linkProps}
    >
      {icon && <Icon icon={icon} className="sidebar-icon flex-shrink-0" />}
      <span className="sidebar-text sidebar-item-label text-truncate">
        {label}
      </span>
    </NavLink>
  );
};

type SidebarItemGroupProps = {
  children: React.ReactNode;
  icon: React.ComponentProps<typeof Icon>["icon"];
  label: React.ReactNode;
  eventKey: string;
  isCollapsed?: boolean;
};

const SidebarItemGroup = ({
  children,
  icon,
  label,
  eventKey,
  isCollapsed,
}: SidebarItemGroupProps) => {
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
          <div className="dropdown-header px-3 pt-1 fw-bold text-uppercase">
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
          <div className="d-flex align-items-center w-100 py-2 rounded text-dark fw-medium">
            <Icon icon={icon} className="sidebar-icon ms-3" />
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
  return (
    <aside
      className={`custom-sidebar d-flex flex-column h-100 position-relative shadow ${
        isDesktopCollapsed ? "collapsed-desktop" : ""
      } ${isMobileMenuOpen ? "mobile-open" : ""}`.trim()}
    >
      {!isMobileMenuOpen && (
        <div className="sidebar-header d-flex align-items-center justify-content-between px-4 shadow-sm">
          <Image
            alt="Clea Edgehog Logo"
            src={isDesktopCollapsed ? assets.images.logo : assets.images.brand}
            className="sidebar-brand-img"
          />

          <Button
            variant="light"
            onClick={onToggleCollapse}
            className="sidebar-collapse-toggle d-none d-md-flex align-items-center justify-content-center"
          >
            <Icon
              icon={isDesktopCollapsed ? "anglesRight" : "anglesLeft"}
              className="text-secondary"
            />
          </Button>
        </div>
      )}

      <nav className="custom-scrollbar d-flex flex-column flex-grow-1 gap-1 overflow-auto py-2">
        <SidebarItem
          label={
            <FormattedMessage
              id="components.Sidebar.devicesLabel"
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

        <SidebarItem
          label={
            <FormattedMessage
              id="components.Sidebar.ChannelsLabel"
              defaultMessage="Channels"
            />
          }
          icon="channels"
          route={Route.channels}
          activeRoutes={[Route.channels, Route.channelsEdit, Route.channelsNew]}
        />

        <SidebarItemGroup
          eventKey="files"
          isCollapsed={isDesktopCollapsed}
          label={
            <FormattedMessage
              id="components.Sidebar.filesManagementGroupLabel"
              defaultMessage="Files Management"
            />
          }
          icon="folder"
        >
          <SidebarItem
            label={
              <FormattedMessage
                id="components.Sidebar.repositoriesLabel"
                defaultMessage="Repositories"
              />
            }
            route={Route.repositories}
            activeRoutes={[
              Route.repositories,
              Route.repositoryNew,
              Route.repositoryEdit,
              Route.filesNew,
            ]}
          />

          <SidebarItem
            label={
              <FormattedMessage
                id="components.Sidebar.fileDownloadCampaignsLabel"
                defaultMessage="File Download Campaigns"
              />
            }
            route={Route.fileDownloadCampaigns}
            activeRoutes={[
              Route.fileDownloadCampaigns,
              Route.fileDownloadCampaignsNew,
              Route.fileDownloadCampaignsEdit,
            ]}
          />
        </SidebarItemGroup>

        <SidebarItemGroup
          eventKey="ota"
          isCollapsed={isDesktopCollapsed}
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
          eventKey="models"
          isCollapsed={isDesktopCollapsed}
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
          eventKey="apps"
          isCollapsed={isDesktopCollapsed}
          label={
            <FormattedMessage
              id="components.Sidebar.applications.applicationsLabel"
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
              Route.releaseNew,
            ]}
          />

          <SidebarItem
            label={
              <FormattedMessage
                id="components.Sidebar.applications.imageCredentialsLabel"
                defaultMessage="Image Credentials"
              />
            }
            route={Route.imageCredentials}
            activeRoutes={[
              Route.imageCredentials,
              Route.imageCredentialsNew,
              Route.imageCredentialsEdit,
            ]}
          />

          <SidebarItem
            label={
              <FormattedMessage
                id="components.Sidebar.applications.volumesLabel"
                defaultMessage="Volumes"
              />
            }
            route={Route.volumes}
            activeRoutes={[Route.volumes, Route.volumeEdit, Route.volumesNew]}
          />

          <SidebarItem
            label={
              <FormattedMessage
                id="components.Sidebar.applications.networksLabel"
                defaultMessage="Networks"
              />
            }
            route={Route.networks}
            activeRoutes={[
              Route.networks,
              Route.networksEdit,
              Route.networksNew,
            ]}
          />

          <SidebarItem
            label={
              <FormattedMessage
                id="components.Sidebar.applications.containersLabel"
                defaultMessage="Containers"
              />
            }
            route={Route.containers}
            activeRoutes={[
              Route.containers,
              Route.containersEdit,
              Route.containersNew,
            ]}
          />

          <SidebarItem
            label={
              <FormattedMessage
                id="components.Sidebar.applications.deploymentsLabel"
                defaultMessage="Deployments"
              />
            }
            route={Route.deployments}
            activeRoutes={[Route.deployments]}
          />

          <SidebarItem
            label={
              <FormattedMessage
                id="components.Sidebar.applications.campaignsLabel"
                defaultMessage="Campaigns"
              />
            }
            route={Route.deploymentCampaigns}
            activeRoutes={[
              Route.deploymentCampaigns,
              Route.deploymentCampaignsEdit,
              Route.deploymentCampaignsNew,
            ]}
          />
        </SidebarItemGroup>
      </nav>

      <div className="sidebar-footer d-flex flex-column align-items-center flex-shrink-0 mb-2 bg-white border-top">
        <div className="sidebar-logout-wrapper w-100 d-flex mt-2">
          <SidebarItem
            label={
              <FormattedMessage
                id="components.Sidebar.logoutLabel"
                defaultMessage="Logout"
              />
            }
            icon="logout"
            route={Route.logout}
            className="w-100 justify-content-center"
          />
        </div>
        <div className="sidebar-meta text-muted fw-semibold text-center">
          <div>
            <span className="sidebar-app-name">{appName}</span>
            <small className="text-secondary opacity-75 ms-1">
              v{appVersion}
            </small>
          </div>

          {(repoUrl || docsUrl) && (
            <div className="sidebar-app-name mt-1">
              {repoUrl && (
                <a
                  href={repoUrl}
                  className="text-reset mx-1"
                  target="_blank"
                  rel="noreferrer"
                >
                  <Icon className="text-black" icon="github" />
                </a>
              )}

              {docsUrl && (
                <a
                  href={docsUrl}
                  className="text-reset mx-1"
                  target="_blank"
                  rel="noreferrer"
                >
                  <Icon className="text-black" icon="documentation" />
                </a>
              )}
            </div>
          )}
        </div>
      </div>
    </aside>
  );
};

export default Sidebar;
