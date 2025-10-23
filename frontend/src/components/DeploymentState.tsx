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

import type { ApplicationDeploymentState } from "api/__generated__/DeployedApplicationsTable_deployedApplications.graphql";

import Icon from "components/Icon";

type DeploymentState =
  | "DEPLOYING"
  | "PENDING"
  | "SENT"
  | "STARTING"
  | "STARTED"
  | "STOPPING"
  | "STOPPED"
  | "ERROR"
  | "DELETING";

const parseDeploymentState = (
  apiState?: ApplicationDeploymentState,
): DeploymentState => {
  switch (apiState) {
    case "PENDING":
      return "PENDING";
    case "SENT":
      return "SENT";
    case "STARTED":
      return "STARTED";
    case "STARTING":
      return "STARTING";
    case "STOPPED":
      return "STOPPED";
    case "STOPPING":
      return "STOPPING";
    case "ERROR":
      return "ERROR";
    case "DELETING":
      return "DELETING";
    default:
      return "DEPLOYING";
  }
};

const stateColors: Record<DeploymentState, string> = {
  PENDING: "text-success",
  SENT: "text-success",
  STARTING: "text-success",
  STARTED: "text-success",
  STOPPING: "text-warning",
  STOPPED: "text-secondary",
  ERROR: "text-danger",
  DELETING: "text-danger",
  DEPLOYING: "text-muted",
};

const stateMessages = defineMessages<DeploymentState>({
  PENDING: {
    id: "components.DeploymentStateComponent.pending",
    defaultMessage: "Pending",
  },
  SENT: {
    id: "components.DeploymentStateComponent.sent",
    defaultMessage: "Sent",
  },
  STARTING: {
    id: "components.DeploymentStateComponent.starting",
    defaultMessage: "Starting",
  },
  STARTED: {
    id: "components.DeploymentStateComponent.started",
    defaultMessage: "Started",
  },
  STOPPING: {
    id: "components.DeploymentStateComponent.stopping",
    defaultMessage: "Stopping",
  },
  STOPPED: {
    id: "components.DeploymentStateComponent.stopped",
    defaultMessage: "Stopped",
  },
  ERROR: {
    id: "components.DeploymentStateComponent.error",
    defaultMessage: "Error",
  },
  DELETING: {
    id: "components.DeploymentStateComponent.deleting",
    defaultMessage: "Deleting",
  },
  DEPLOYING: {
    id: "components.DeploymentStateComponent.deploying",
    defaultMessage: "Deploying",
  },
});

const displaySpinner = (state: string, isReady?: boolean | null) => {
  return (
    !isReady ||
    ["STARTING", "STOPPING", "DEPLOYING", "DELETING"].includes(state)
  );
};

type DeploymentStateComponentProps = {
  state: DeploymentState;
  isReady?: boolean | null;
};

const DeploymentStateComponent = ({
  state,
  isReady,
}: DeploymentStateComponentProps) => {
  const displayedState = isReady ? state : "DEPLOYING";

  return (
    <div className="d-flex align-items-center">
      <Icon
        icon={displaySpinner(state, isReady) ? "spinner" : "circle"}
        className={`me-2 ${stateColors[displayedState]} ${displaySpinner(state, isReady) ? "fa-spin" : ""}`}
      />
      <FormattedMessage id={stateMessages[displayedState].id} />
    </div>
  );
};

export type { DeploymentState };
export { parseDeploymentState };
export default DeploymentStateComponent;
