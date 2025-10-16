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

import Icon from "components/Icon";

type ContainerState =
  | "CREATED"
  | "RUNNING"
  | "PAUSED"
  | "RESTARTING"
  | "REMOVING"
  | "EXITED"
  | "DEAD"
  | "UNKNOWN";

function parseContainerState(state?: string): ContainerState {
  switch (state?.toLowerCase()) {
    case "created":
      return "CREATED";
    case "running":
      return "RUNNING";
    case "paused":
      return "PAUSED";
    case "restarting":
      return "RESTARTING";
    case "removing":
      return "REMOVING";
    case "exited":
    case "stopped":
      return "EXITED";
    case "dead":
      return "DEAD";
    default:
      return "UNKNOWN";
  }
}

const stateColors: Record<ContainerState, string> = {
  CREATED: "text-secondary",
  RUNNING: "text-success",
  PAUSED: "text-warning",
  RESTARTING: "text-warning",
  REMOVING: "text-warning",
  EXITED: "text-secondary",
  DEAD: "text-danger",
  UNKNOWN: "text-muted",
};

const stateMessages = defineMessages<ContainerState>({
  CREATED: {
    id: "components.ContainerStatus.created",
    defaultMessage: "Created",
  },
  RUNNING: {
    id: "components.ContainerStatus.running",
    defaultMessage: "Running",
  },
  PAUSED: {
    id: "components.ContainerStatus.paused",
    defaultMessage: "Paused",
  },
  RESTARTING: {
    id: "components.ContainerStatus.restarting",
    defaultMessage: "Restarting",
  },
  REMOVING: {
    id: "components.ContainerStatus.removing",
    defaultMessage: "Removing",
  },
  EXITED: {
    id: "components.ContainerStatus.exited",
    defaultMessage: "Exited",
  },
  DEAD: {
    id: "components.ContainerStatus.dead",
    defaultMessage: "Dead",
  },
  UNKNOWN: {
    id: "components.ContainerStatus.unknown",
    defaultMessage: "Unknown",
  },
});

const stateIcons: Record<
  ContainerState,
  React.ComponentProps<typeof Icon>["icon"]
> = {
  CREATED: "circle",
  RUNNING: "circle",
  PAUSED: "circle",
  RESTARTING: "spinner",
  REMOVING: "spinner",
  EXITED: "circle",
  DEAD: "circle",
  UNKNOWN: "circle",
};

type ContainerStatusProps = {
  state: ContainerState;
};

const ContainerStatusComponent = ({ state }: ContainerStatusProps) => {
  return (
    <div className="d-flex align-items-center small">
      <Icon
        icon={stateIcons[state]}
        className={`me-2 ${stateColors[state]} ${
          ["RESTARTING", "REMOVING"].includes(state) ? "fa-spin" : ""
        }`}
      />
      <FormattedMessage id={stateMessages[state].id} />
    </div>
  );
};

export type { ContainerState };
export { parseContainerState };

export default ContainerStatusComponent;
