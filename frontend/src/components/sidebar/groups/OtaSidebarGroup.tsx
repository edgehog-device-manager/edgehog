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

type OtaSidebarGroupProps = {
  collapsed: boolean;
};

const OtaSidebarGroup = ({ collapsed }: OtaSidebarGroupProps) => {
  return (
    <SidebarGroup
      eventKey="ota"
      isCollapsed={collapsed}
      label={
        <FormattedMessage
          id="components.sidebar.groups.OtaSidebarGroup.otaUpdatesGroupLabel"
          defaultMessage="OTA Updates"
        />
      }
      icon="otaUpdates"
    >
      <SidebarItem
        label={
          <FormattedMessage
            id="components.sidebar.groups.OtaSidebarGroup.baseImageCollectionsLabel"
            defaultMessage="Base Image Collections"
          />
        }
        icon="baseImageCollections"
        route={Route.baseImageCollections}
        activeRoutes={[
          Route.baseImageCollections,
          Route.baseImageCollectionsNew,
          Route.baseImageCollectionsEdit,
          Route.baseImagesNew,
          Route.baseImagesEdit,
        ]}
      />
      <SidebarItem
        label={
          <FormattedMessage
            id="components.sidebar.groups.OtaSidebarGroup.updateCampaignsLabel"
            defaultMessage="Update Campaigns"
          />
        }
        icon="campaign"
        route={Route.updateCampaigns}
        activeRoutes={[Route.updateCampaigns, Route.updateCampaignsEdit]}
      />
    </SidebarGroup>
  );
};

export type { OtaSidebarGroupProps };
export default OtaSidebarGroup;
