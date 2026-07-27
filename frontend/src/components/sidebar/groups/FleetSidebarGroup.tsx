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

type FleetSidebarGroupProps = {
  collapsed: boolean;
};

const FleetSidebarGroup = ({ collapsed }: FleetSidebarGroupProps) => {
  return (
    <SidebarGroup
      eventKey="fleet"
      isCollapsed={collapsed}
      label={
        <FormattedMessage
          id="components.sidebar.groups.FleetSidebarGroup.fleetGroupLabel"
          defaultMessage="Fleet Management"
        />
      }
      icon="fleet"
    >
      <SidebarItem
        label={
          <FormattedMessage
            id="components.sidebar.groups.FleetSidebarGroup.hardwareTypesLabel"
            defaultMessage="Hardware Types"
          />
        }
        route={Route.hardwareTypes}
        icon="hardwareTypes"
        activeRoutes={[
          Route.hardwareTypes,
          Route.hardwareTypesNew,
          Route.hardwareTypesEdit,
        ]}
      />
      <SidebarItem
        label={
          <FormattedMessage
            id="components.sidebar.groups.FleetSidebarGroup.modelsLabel"
            defaultMessage="System Models"
          />
        }
        route={Route.systemModels}
        icon="systemModels"
        activeRoutes={[
          Route.systemModels,
          Route.systemModelsNew,
          Route.systemModelsEdit,
        ]}
      />
      <SidebarItem
        label={
          <FormattedMessage
            id="components.sidebar.groups.FleetSidebarGroup.deviceGroupsLabel"
            defaultMessage="Groups"
          />
        }
        route={Route.deviceGroups}
        icon="deviceGroups"
        activeRoutes={[
          Route.deviceGroups,
          Route.deviceGroupsEdit,
          Route.deviceGroupsNew,
        ]}
      />
      <SidebarItem
        label={
          <FormattedMessage
            id="components.sidebar.groups.FleetSidebarGroup.ChannelsLabel"
            defaultMessage="Channels"
          />
        }
        icon="channels"
        route={Route.channels}
        activeRoutes={[Route.channels, Route.channelsEdit, Route.channelsNew]}
      />
    </SidebarGroup>
  );
};

export type { FleetSidebarGroupProps };
export default FleetSidebarGroup;
