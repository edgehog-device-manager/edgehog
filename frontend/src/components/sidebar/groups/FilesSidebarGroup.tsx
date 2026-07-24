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

type FilesSidebarGroupProps = {
  collapsed: boolean;
};

const FilesSidebarGroup = ({ collapsed }: FilesSidebarGroupProps) => {
  return (
    <SidebarGroup
      eventKey="files"
      isCollapsed={collapsed}
      label={
        <FormattedMessage
          id="components.sidebar.groups.FilesSidebarGroup.filesManagementGroupLabel"
          defaultMessage="Files Management"
        />
      }
      icon="folder"
    >
      <SidebarItem
        label={
          <FormattedMessage
            id="components.sidebar.groups.FilesSidebarGroup.repositoriesLabel"
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
            id="components.sidebar.groups.FilesSidebarGroup.fileDownloadCampaignsLabel"
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
    </SidebarGroup>
  );
};

export type { FilesSidebarGroupProps };
export default FilesSidebarGroup;
