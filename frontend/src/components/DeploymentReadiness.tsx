/*
 * This file is part of Edgehog.
 *
 * Copyright 2025 SECO Mind Srl
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

import { defineMessages, FormattedMessage } from "react-intl";

import Icon from "@/components/Icon";

const deploymentReadinessMessages = defineMessages({
  READY: {
    id: "components.DeploymentReadiness.ready",
    defaultMessage: "Ready",
  },
  NOT_READY: {
    id: "components.DeploymentReadiness.notReady",
    defaultMessage: "Deploying",
  },
});

type DeploymentReadinessProps = {
  isReady: boolean | null | undefined;
};

const DeploymentReadiness = ({ isReady }: DeploymentReadinessProps) => {
  const icon = isReady ? (
    <Icon icon="circle" className="me-2 text-success" />
  ) : (
    <Icon icon="spinner" className="me-2 text-muted fa-spin" />
  );
  return (
    <div className="d-flex align-items-center">
      {icon}
      <FormattedMessage
        id={deploymentReadinessMessages[isReady ? "READY" : "NOT_READY"].id}
      />
    </div>
  );
};

export default DeploymentReadiness;
