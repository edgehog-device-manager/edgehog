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

import { FormattedMessage } from "react-intl";

import SidebarItem from "@/components/sidebar/SidebarItem";
import SidebarGroup from "@/components/sidebar/SidebarGroup";

import { Route } from "@/Navigation";

type AppsSidebarGroupProps = {
  collapsed: boolean;
};

const AppsSidebarGroup = ({ collapsed }: AppsSidebarGroupProps) => {
  return (
    <SidebarGroup
      eventKey="apps"
      isCollapsed={collapsed}
      label={
        <FormattedMessage
          id="components.sidebar.groups.AppsSidebarGroup.applicationsLabel"
          defaultMessage="Applications"
        />
      }
      icon="applications"
    >
      <SidebarItem
        label={
          <FormattedMessage
            id="components.sidebar.groups.AppsSidebarGroup.imageCredentialsLabel"
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
            id="components.sidebar.groups.AppsSidebarGroup.volumesLabel"
            defaultMessage="Volumes"
          />
        }
        route={Route.volumes}
        activeRoutes={[Route.volumes, Route.volumeEdit, Route.volumesNew]}
      />

      <SidebarItem
        label={
          <FormattedMessage
            id="components.sidebar.groups.AppsSidebarGroup.networksLabel"
            defaultMessage="Networks"
          />
        }
        route={Route.networks}
        activeRoutes={[Route.networks, Route.networksEdit, Route.networksNew]}
      />

      <SidebarItem
        label={
          <FormattedMessage
            id="components.sidebar.groups.AppsSidebarGroup.containersLabel"
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
            id="components.sidebar.groups.AppsSidebarGroup.applicationsLabel"
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
            id="components.sidebar.groups.AppsSidebarGroup.deploymentsLabel"
            defaultMessage="Deployments"
          />
        }
        route={Route.deployments}
        activeRoutes={[Route.deployments]}
      />

      <SidebarItem
        label={
          <FormattedMessage
            id="components.sidebar.groups.AppsSidebarGroup.campaignsLabel"
            defaultMessage="Application Campaigns"
          />
        }
        route={Route.deploymentCampaigns}
        activeRoutes={[
          Route.deploymentCampaigns,
          Route.deploymentCampaignsEdit,
          Route.deploymentCampaignsNew,
        ]}
      />
    </SidebarGroup>
  );
};

export type { AppsSidebarGroupProps };
export default AppsSidebarGroup;
