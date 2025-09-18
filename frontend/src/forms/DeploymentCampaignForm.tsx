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

import type { ReactNode } from "react";
import { FormattedMessage } from "react-intl";
import { graphql, useFragment } from "react-relay/hooks";

import type {
  DeploymentCampaignForm_DeploymentCampaignFragment$data,
  DeploymentCampaignForm_DeploymentCampaignFragment$key,
} from "api/__generated__/DeploymentCampaignForm_DeploymentCampaignFragment.graphql";

import Col from "components/Col";
import Row from "components/Row";
import DeploymentCampaignOutcome from "components/DeploymentCampaignOutcome";
import DeploymentCampaignStatus from "components/DeploymentCampaignStatus";
import { Link, Route } from "Navigation";

// We use graphql fields below in columns configuration
/* eslint-disable relay/unused-fields */
const DEPLOYMENT_CAMPAIGN_FORM_FRAGMENT = graphql`
  fragment DeploymentCampaignForm_DeploymentCampaignFragment on DeploymentCampaign {
    ...DeploymentCampaignStatus_DeploymentCampaignStatusFragment
    ...DeploymentCampaignOutcome_DeploymentCampaignOutcomeFragment
    channel {
      id
      name
    }
    release {
      id
      version
      applicationId
    }
    deploymentMechanism {
      __typename
      ... on DeploymentMechanism {
        ... on Lazy {
          maxFailurePercentage
          maxInProgressDeployments
          createRequestRetries
          requestTimeoutSeconds
        }
      }
    }
  }
`;

const FormRow = ({
  label,
  children,
}: {
  label: ReactNode;
  children: ReactNode;
}) => (
  <Row>
    <Col sm={4} lg>
      {label}
    </Col>
    <Col sm={8} lg>
      {children}
    </Col>
  </Row>
);

type RolloutMechanismColProps = {
  rolloutMechanism: DeploymentCampaignForm_DeploymentCampaignFragment$data["deploymentMechanism"];
};
const RolloutMechanismCol = ({
  rolloutMechanism,
}: RolloutMechanismColProps) => {
  if (rolloutMechanism.__typename !== "Lazy") {
    return null;
  }

  return (
    <Col lg>
      <FormRow
        label={
          <FormattedMessage
            id="forms.DeploymentCampaignForm.rolloutMechanism.maxInProgressDeploymentsLabel"
            defaultMessage="Max Pending Operations"
          />
        }
      >
        {rolloutMechanism.maxInProgressDeployments}
      </FormRow>
      <FormRow
        label={
          <FormattedMessage
            id="forms.DeploymentCampaignForm.rolloutMechanism.maxFailurePercentageLabel"
            defaultMessage="Max Failures <muted>(%)</muted>"
            values={{
              muted: (chunks: React.ReactNode) => (
                <span className="small text-muted">{chunks}</span>
              ),
            }}
          />
        }
      >
        {rolloutMechanism.maxFailurePercentage}
      </FormRow>
      <FormRow
        label={
          <FormattedMessage
            id="forms.DeploymentCampaignForm.rolloutMechanism.otaRequestTimeoutSeconds"
            defaultMessage="Request Timeout <muted>(seconds)</muted>"
            values={{
              muted: (chunks: React.ReactNode) => (
                <span className="small text-muted">{chunks}</span>
              ),
            }}
          />
        }
      >
        {rolloutMechanism.requestTimeoutSeconds}
      </FormRow>
      <FormRow
        label={
          <FormattedMessage
            id="forms.DeploymentCampaignForm.rolloutMechanism.otaRequestRetriesLabel"
            defaultMessage="Request Retries"
          />
        }
      >
        {rolloutMechanism.createRequestRetries}
      </FormRow>
    </Col>
  );
};

type DeploymentCampaignProps = {
  deploymentCampaignRef: DeploymentCampaignForm_DeploymentCampaignFragment$key;
};

const DeploymentCampaign = ({
  deploymentCampaignRef,
}: DeploymentCampaignProps) => {
  const deploymentCampaign = useFragment(
    DEPLOYMENT_CAMPAIGN_FORM_FRAGMENT,
    deploymentCampaignRef,
  );

  const { release, channel, deploymentMechanism } = deploymentCampaign;
  return (
    <Row>
      <Col lg>
        <FormRow
          label={
            <FormattedMessage
              id="forms.DeploymentCampaignForm.statusLabel"
              defaultMessage="Status"
            />
          }
        >
          <DeploymentCampaignStatus
            deploymentCampaignRef={deploymentCampaign}
          />
        </FormRow>
        <FormRow
          label={
            <FormattedMessage
              id="forms.DeploymentCampaignForm.outcomeLabel"
              defaultMessage="Outcome"
            />
          }
        >
          <DeploymentCampaignOutcome
            deploymentCampaignRef={deploymentCampaign}
          />
        </FormRow>

        <FormRow
          label={
            <FormattedMessage
              id="forms.DeploymentCampaignForm.deploymentChannelLabel"
              defaultMessage="Deployment Channel"
            />
          }
        >
          <Link route={Route.channelsEdit} params={{ channelId: channel.id }}>
            {channel.name}
          </Link>
        </FormRow>
        <FormRow
          label={
            <FormattedMessage
              id="forms.DeploymentCampaignForm.releaseLabel"
              defaultMessage="Release"
            />
          }
        >
          <Link
            route={Route.release}
            params={{
              applicationId: release.applicationId || "",
              releaseId: release.id,
            }}
          >
            {release.version}
          </Link>
        </FormRow>
      </Col>
      <RolloutMechanismCol rolloutMechanism={deploymentMechanism} />
    </Row>
  );
};

export default DeploymentCampaign;
