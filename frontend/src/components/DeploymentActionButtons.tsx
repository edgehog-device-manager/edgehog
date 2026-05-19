/*
  This file is part of Edgehog.

  Copyright 2026 SECO Mind Srl

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

import { useIntl } from "react-intl";

import Button from "@/components/Button";
import "@/components/DeploymentActionButtons.scss";
import type { DeploymentState } from "@/components/DeploymentState";
import Icon from "@/components/Icon";

type DeploymentActionButtonsProps = {
  state: DeploymentState;
  isReady: boolean | null;
  isDeleting?: boolean;
  onStart: () => void;
  onStop: () => void;
  onRedeploy: () => void;
  onUpgrade: () => void;
  onDelete: () => void;
};

const DeploymentActionButtons = ({
  state,
  isReady,
  isDeleting,
  onStart,
  onStop,
  onRedeploy,
  onUpgrade,
  onDelete,
}: DeploymentActionButtonsProps) => {
  const intl = useIntl();

  const isNotReady = !isReady;

  const deploymentActionButton = (() => {
    if (isNotReady) {
      return (
        <Button
          className="btn p-0 border-0 bg-transparent icon-click"
          title={intl.formatMessage({
            id: "components.DeploymentActionButtons.sendButtonTitle",
            defaultMessage: "Redeploy Application",
          })}
          onClick={onRedeploy}
        >
          <Icon className="text-dark" icon="rotate" />
        </Button>
      );
    }

    if (state === "STOPPED" || state === "ERROR") {
      return (
        <Button
          onClick={onStart}
          className="btn p-0 border-0 bg-transparent icon-click"
          title={intl.formatMessage({
            id: "components.DeploymentActionButtons.startButtonTitle",
            defaultMessage: "Start Deployment",
          })}
        >
          <Icon icon="play" className="text-success" />
        </Button>
      );
    }

    if (state === "STARTED") {
      return (
        <Button
          onClick={onStop}
          className="btn p-0 border-0 bg-transparent icon-click"
          title={intl.formatMessage({
            id: "components.DeploymentActionButtons.stopButtonTitle",
            defaultMessage: "Stop Deployment",
          })}
        >
          <Icon icon="stop" className="text-danger" />
        </Button>
      );
    }

    return (
      <Button className="btn p-0 border-0 bg-transparent" disabled>
        <Icon
          icon={state === "STARTING" || state === "DEPLOYING" ? "play" : "stop"}
          className="text-muted"
        />
      </Button>
    );
  })();

  return (
    <div className="d-flex align-items-center gap-2">
      {deploymentActionButton}

      <Button
        onClick={onUpgrade}
        disabled={isDeleting || isNotReady}
        className="btn p-0 border-0 bg-transparent icon-click"
        title={intl.formatMessage({
          id: "components.DeploymentActionButtons.upgradeButtonTitle",
          defaultMessage: "Upgrade Deployment",
        })}
      >
        <Icon icon="upgrade" className="text-primary" />
      </Button>

      <Button
        onClick={onDelete}
        disabled={isDeleting || isNotReady}
        className="btn p-0 border-0 bg-transparent icon-click"
        title={intl.formatMessage({
          id: "components.DeploymentActionButtons.deleteButtonTitle",
          defaultMessage: "Delete Deployment",
        })}
      >
        <Icon icon="delete" className="text-danger" />
      </Button>
    </div>
  );
};

export default DeploymentActionButtons;
