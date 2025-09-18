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
import { graphql, useFragment } from "react-relay/hooks";

import type {
  DeploymentTargetStatus as DeploymentTargetStatusType,
  DeploymentTargetStatus_DeploymentTargetStatusFragment$key,
} from "api/__generated__/DeploymentTargetStatus_DeploymentTargetStatusFragment.graphql";

import Icon from "components/Icon";
import "./DeploymentTargetStatus.scss";

const DEPLOYMENT_TARGET_STATUS_FRAGMENT = graphql`
  fragment DeploymentTargetStatus_DeploymentTargetStatusFragment on DeploymentTarget {
    status
  }
`;

const messages = defineMessages<DeploymentTargetStatusType>({
  IDLE: {
    id: "components.deploymentTargetStatus.Idle",
    defaultMessage: "Idle",
  },
  IN_PROGRESS: {
    id: "components.deploymentTargetStatus.InProgress",
    defaultMessage: "In progress",
  },
  SUCCESSFUL: {
    id: "components.deploymentTargetStatus.Successful",
    defaultMessage: "Successful",
  },
  FAILED: {
    id: "components.deploymentTargetStatus.Failed",
    defaultMessage: "Failed",
  },
});

const colors: Record<DeploymentTargetStatusType, string> = {
  IDLE: "color-idle",
  IN_PROGRESS: "color-in-progress",
  SUCCESSFUL: "color-successful",
  FAILED: "color-failed",
};

type DeploymentTargetStatusProps = {
  status: DeploymentTargetStatusType;
};
const DeploymentTargetStatus = ({ status }: DeploymentTargetStatusProps) => (
  <span className="deployment-target-status text-nowrap">
    <Icon icon="circle" className={`me-2 ${colors[status]}`} />
    <FormattedMessage id={messages[status].id} />
  </span>
);

type DeploymentTargetStatusFragmentProps = {
  deploymentTargetRef: DeploymentTargetStatus_DeploymentTargetStatusFragment$key;
};
const DeploymentTargetStatusFragment = ({
  deploymentTargetRef,
}: DeploymentTargetStatusFragmentProps) => {
  const { status } = useFragment(
    DEPLOYMENT_TARGET_STATUS_FRAGMENT,
    deploymentTargetRef,
  );
  return <DeploymentTargetStatus status={status} />;
};

type DeploymentTargetStatusWrapperProps =
  | {
      status: DeploymentTargetStatusType;
      deploymentTargetRef?: never;
    }
  | {
      status?: never;
      deploymentTargetRef: DeploymentTargetStatus_DeploymentTargetStatusFragment$key;
    };

const DeploymentTargetStatusWrapper = (
  props: DeploymentTargetStatusWrapperProps,
) =>
  props.deploymentTargetRef ? (
    <DeploymentTargetStatusFragment
      deploymentTargetRef={props.deploymentTargetRef}
    />
  ) : (
    <DeploymentTargetStatus status={props.status} />
  );

export type { DeploymentTargetStatusType };
export { messages as statusMessages };

export default DeploymentTargetStatusWrapper;
