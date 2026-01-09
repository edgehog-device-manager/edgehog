/*
 * This file is part of Edgehog.
 *
 * Copyright 2025 - 2026 SECO Mind Srl
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
import { graphql, useFragment } from "react-relay/hooks";

import type {
  DeploymentCampaignForm_CampaignFragment$data,
  DeploymentCampaignForm_CampaignFragment$key,
} from "@/api/__generated__/DeploymentCampaignForm_CampaignFragment.graphql";

import Col from "@/components/Col";
import Row from "@/components/Row";
import CampaignOutcome from "@/components/CampaignOutcome";
import CampaignStatus from "@/components/CampaignStatus";
import { SimpleFormRow as FormRow } from "@/components/FormRow";
import { Link, Route } from "@/Navigation";
import { OperationType } from "./CreateDeploymentCampaign";

// We use graphql fields below in columns configuration
/* eslint-disable relay/unused-fields */
const CAMPAIGN_FORM_FRAGMENT = graphql`
  fragment DeploymentCampaignForm_CampaignFragment on Campaign {
    ...CampaignStatus_CampaignStatusFragment
    ...CampaignOutcome_CampaignOutcomeFragment
    channel {
      id
      name
    }
    campaignMechanism {
      __typename
      ... on DeploymentDeploy {
        maxFailurePercentage
        maxInProgressOperations
        requestRetries
        requestTimeoutSeconds
        release {
          id
          version
          application {
            id
            name
          }
        }
      }
      ... on DeploymentStart {
        maxFailurePercentage
        maxInProgressOperations
        requestRetries
        requestTimeoutSeconds
        release {
          id
          version
          application {
            id
            name
          }
        }
      }
      ... on DeploymentStop {
        maxFailurePercentage
        maxInProgressOperations
        requestRetries
        requestTimeoutSeconds
        release {
          id
          version
          application {
            id
            name
          }
        }
      }
      ... on DeploymentDelete {
        maxFailurePercentage
        maxInProgressOperations
        requestRetries
        requestTimeoutSeconds
        release {
          id
          version
          application {
            id
            name
          }
        }
      }
      ... on DeploymentUpgrade {
        maxFailurePercentage
        maxInProgressOperations
        requestRetries
        requestTimeoutSeconds
        release {
          id
          version
          application {
            id
            name
          }
        }
        targetRelease {
          id
          version
        }
      }
    }
  }
`;

const MECHANISM_TO_OPERATION: Record<string, OperationType> = {
  DeploymentDeploy: "Deploy",
  DeploymentStart: "Start",
  DeploymentStop: "Stop",
  DeploymentUpgrade: "Upgrade",
  DeploymentDelete: "Delete",
};

type CampaignMechanismColProps = {
  campaignMechanism: DeploymentCampaignForm_CampaignFragment$data["campaignMechanism"];
};

const CampaignMechanismCol = ({
  campaignMechanism,
}: CampaignMechanismColProps) => {
  if (campaignMechanism.__typename === "%other") {
    return null;
  }

  return (
    <Col lg>
      <FormRow
        label={
          <FormattedMessage
            id="forms.DeploymentCampaignForm.maxInProgressOperations"
            defaultMessage="Max Pending Operations"
          />
        }
      >
        {campaignMechanism.maxInProgressOperations}
      </FormRow>

      <FormRow
        label={
          <FormattedMessage
            id="forms.DeploymentCampaignForm.campaignMechanism.maxFailurePercentageLabel"
            defaultMessage="Max Failures <muted>(%)</muted>"
            values={{
              muted: (chunks: React.ReactNode) => (
                <span className="small text-muted">{chunks}</span>
              ),
            }}
          />
        }
      >
        {campaignMechanism.maxFailurePercentage}
      </FormRow>

      <FormRow
        label={
          <FormattedMessage
            id="forms.DeploymentCampaignForm.campaignMechanism.requestTimeoutSeconds"
            defaultMessage="Request Timeout <muted>(seconds)</muted>"
            values={{
              muted: (chunks: React.ReactNode) => (
                <span className="small text-muted">{chunks}</span>
              ),
            }}
          />
        }
      >
        {campaignMechanism.requestTimeoutSeconds}
      </FormRow>

      <FormRow
        label={
          <FormattedMessage
            id="forms.DeploymentCampaignForm.requestRetries"
            defaultMessage="Request Retries"
          />
        }
      >
        {campaignMechanism.requestRetries}
      </FormRow>
    </Col>
  );
};

type DeploymentCampaignProps = {
  campaignRef: DeploymentCampaignForm_CampaignFragment$key;
};

const DeploymentCampaign = ({ campaignRef }: DeploymentCampaignProps) => {
  const campaign = useFragment(CAMPAIGN_FORM_FRAGMENT, campaignRef);

  const { channel, campaignMechanism } = campaign;

  const operationType = MECHANISM_TO_OPERATION[campaignMechanism.__typename];

  const release =
    "release" in campaignMechanism ? campaignMechanism.release : null;

  const targetRelease =
    campaignMechanism.__typename === "DeploymentUpgrade"
      ? campaignMechanism.targetRelease
      : null;

  return (
    <Row>
      <Col lg>
        <FormRow
          label={
            <FormattedMessage
              id="forms.DeploymentCampaignForm.operationTypeLabel"
              defaultMessage="Operation Type"
            />
          }
        >
          {operationType}
        </FormRow>

        <FormRow
          label={
            <FormattedMessage
              id="forms.DeploymentCampaignForm.statusLabel"
              defaultMessage="Status"
            />
          }
        >
          <CampaignStatus campaignRef={campaign} />
        </FormRow>

        <FormRow
          label={
            <FormattedMessage
              id="forms.DeploymentCampaignForm.outcomeLabel"
              defaultMessage="Outcome"
            />
          }
        >
          <CampaignOutcome campaignRef={campaign} />
        </FormRow>

        {release?.application && (
          <>
            <FormRow
              label={
                <FormattedMessage
                  id="forms.DeploymentCampaignForm.applicationLabel"
                  defaultMessage="Application"
                />
              }
            >
              <Link
                route={Route.application}
                params={{ applicationId: release.application.id }}
              >
                {release.application.name}
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
                  applicationId: release.application.id,
                  releaseId: release.id,
                }}
              >
                {release.version}
              </Link>
            </FormRow>
          </>
        )}

        {campaignMechanism.__typename === "DeploymentUpgrade" &&
          targetRelease &&
          release?.application && (
            <FormRow
              label={
                <FormattedMessage
                  id="forms.DeploymentCampaignForm.targetReleaseLabel"
                  defaultMessage="Target Release"
                />
              }
            >
              <Link
                route={Route.release}
                params={{
                  applicationId: release?.application.id ?? "",
                  releaseId: targetRelease.id,
                }}
              >
                {targetRelease.version}
              </Link>
            </FormRow>
          )}

        <FormRow
          label={
            <FormattedMessage
              id="forms.DeploymentCampaignForm.channelLabel"
              defaultMessage="Channel"
            />
          }
        >
          <Link route={Route.channelsEdit} params={{ channelId: channel.id }}>
            {channel.name}
          </Link>
        </FormRow>
      </Col>

      <CampaignMechanismCol campaignMechanism={campaignMechanism} />
    </Row>
  );
};

export default DeploymentCampaign;
