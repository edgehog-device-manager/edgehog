/*
  This file is part of Edgehog.

  Copyright 2025 SECO Mind Srl

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

import { defineMessages, FormattedMessage } from "react-intl";

import type { ApplicationDeploymentResourcesState } from "api/__generated__/DeployedApplicationsTable_deployedApplications.graphql";

import Icon from "components/Icon";

type DeploymentResourcesState =
  | "INITIAL"
  | "CREATED_IMAGES"
  | "CREATED_NETWORKS"
  | "CREATED_VOLUMES"
  | "CREATED_DEVICE_MAPPINGS"
  | "CREATED_CONTAINERS"
  | "READY";

const parseDeploymentResourcesState = (
  apiState?: ApplicationDeploymentResourcesState,
): DeploymentResourcesState => {
  switch (apiState) {
    case "INITIAL":
      return "INITIAL";
    case "CREATED_IMAGES":
      return "CREATED_IMAGES";
    case "CREATED_NETWORKS":
      return "CREATED_NETWORKS";
    case "CREATED_VOLUMES":
      return "CREATED_VOLUMES";
    case "CREATED_DEVICE_MAPPINGS":
      return "CREATED_DEVICE_MAPPINGS";
    case "CREATED_CONTAINERS":
      return "CREATED_CONTAINERS";
    case "READY":
      return "READY";
    default:
      return "INITIAL";
  }
};

const resourcesStateColors: Record<DeploymentResourcesState, string> = {
  INITIAL: "text-muted",
  CREATED_IMAGES: "text-muted",
  CREATED_NETWORKS: "text-muted",
  CREATED_VOLUMES: "text-muted",
  CREATED_DEVICE_MAPPINGS: "text-muted",
  CREATED_CONTAINERS: "text-muted",
  READY: "text-success",
};

const resourcesStateMessages = defineMessages<DeploymentResourcesState>({
  INITIAL: {
    id: "components.DeploymentResourcesStateComponent.initial",
    defaultMessage: "Initial",
  },
  CREATED_IMAGES: {
    id: "components.DeploymentResourcesStateComponent.createdImages",
    defaultMessage: "Created images",
  },
  CREATED_NETWORKS: {
    id: "components.DeploymentResourcesStateComponent.createdNetworks",
    defaultMessage: "Created networks",
  },
  CREATED_VOLUMES: {
    id: "components.DeploymentResourcesStateComponent.createdVolumes",
    defaultMessage: "Created volumes",
  },
  CREATED_DEVICE_MAPPINGS: {
    id: "components.DeploymentResourcesStateComponent.createdDeviceMappings",
    defaultMessage: "Created device mappings",
  },
  CREATED_CONTAINERS: {
    id: "components.DeploymentResourcesStateComponent.createdContainers",
    defaultMessage: "Created containers",
  },
  READY: {
    id: "components.DeploymentResourcesStateComponent.ready",
    defaultMessage: "Ready",
  },
});

type DeploymentResourcesStateComponentProps = {
  resourcesState: DeploymentResourcesState;
};

const DeploymentResourcesStateComponent = ({
  resourcesState,
}: DeploymentResourcesStateComponentProps) => {
  return (
    <div className="d-flex align-items-center">
      <Icon
        icon={resourcesState !== "READY" ? "spinner" : "circle"}
        className={`me-2 ${resourcesStateColors[resourcesState]} ${
          resourcesState !== "READY" ? "fa-spin" : ""
        }`}
      />
      <FormattedMessage id={resourcesStateMessages[resourcesState].id} />
    </div>
  );
};

export type { DeploymentResourcesState };
export { parseDeploymentResourcesState };
export default DeploymentResourcesStateComponent;
