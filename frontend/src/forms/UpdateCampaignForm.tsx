/*
  This file is part of Edgehog.

  Copyright 2023 SECO Mind Srl

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

import type { UpdateCampaignForm_UpdateCampaignFragment$key } from "api/__generated__/UpdateCampaignForm_UpdateCampaignFragment.graphql";

import Col from "components/Col";
import Form from "components/Form";
import Row from "components/Row";
import UpdateCampaignOutcome from "components/UpdateCampaignOutcome";
import UpdateCampaignStatus from "components/UpdateCampaignStatus";
import { Link, Route } from "Navigation";

// We use graphql fields below in columns configuration
/* eslint-disable relay/unused-fields */
const UPDATE_CAMPAIGN_FORM_FRAGMENT = graphql`
  fragment UpdateCampaignForm_UpdateCampaignFragment on UpdateCampaign {
    ...UpdateCampaignStatus_UpdateCampaignStatusFragment
    ...UpdateCampaignOutcome_UpdateCampaignOutcomeFragment
    baseImage {
      id
      version
      releaseDisplayName
      baseImageCollection {
        id
        name
      }
    }
    updateChannel {
      id
      name
    }
    rolloutMechanism {
      ... on PushRollout {
        maxErrorsPercentage
        maxInProgressUpdates
        otaRequestRetries
        otaRequestTimeoutSeconds
        forceDowngrade
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
    <Col sm={4}>{label}</Col>
    <Col sm={8}>{children}</Col>
  </Row>
);

type UpdateCampaignProps = {
  updateCampaignRef: UpdateCampaignForm_UpdateCampaignFragment$key;
};

const UpdateCampaign = ({ updateCampaignRef }: UpdateCampaignProps) => {
  const updateCampaign = useFragment(
    UPDATE_CAMPAIGN_FORM_FRAGMENT,
    updateCampaignRef
  );

  const { baseImage, updateChannel, rolloutMechanism } = updateCampaign;
  const { baseImageCollection } = baseImage;
  const {
    maxInProgressUpdates,
    maxErrorsPercentage,
    otaRequestTimeoutSeconds,
    otaRequestRetries,
    forceDowngrade,
  } = rolloutMechanism;
  return (
    <Row>
      <Col lg>
        <FormRow
          label={
            <FormattedMessage
              id="forms.UpdateCampaignForm.statusLabel"
              defaultMessage="Status"
            />
          }
        >
          <UpdateCampaignStatus updateCampaignRef={updateCampaign} />
        </FormRow>
        <FormRow
          label={
            <FormattedMessage
              id="forms.UpdateCampaignForm.outcomeLabel"
              defaultMessage="Outcome"
            />
          }
        >
          <UpdateCampaignOutcome updateCampaignRef={updateCampaign} />
        </FormRow>
        <FormRow
          label={
            <FormattedMessage
              id="forms.UpdateCampaignForm.baseImageCollectionLabel"
              defaultMessage="Base Image Collection"
            />
          }
        >
          <Link
            route={Route.baseImageCollectionsEdit}
            params={{ baseImageCollectionId: baseImageCollection.id }}
          >
            {baseImageCollection.name}
          </Link>
        </FormRow>
        <FormRow
          label={
            <FormattedMessage
              id="forms.UpdateCampaignForm.baseImageLabel"
              defaultMessage="Base Image"
            />
          }
        >
          <Link
            route={Route.baseImagesEdit}
            params={{
              baseImageCollectionId: baseImageCollection.id,
              baseImageId: baseImage.id,
            }}
          >
            {baseImage.version}
            {baseImage.releaseDisplayName !== null
              ? ` (${baseImage.releaseDisplayName})`
              : ""}
          </Link>
        </FormRow>
        <FormRow
          label={
            <FormattedMessage
              id="forms.UpdateCampaignForm.updateChannelLabel"
              defaultMessage="Update Channel"
            />
          }
        >
          <Link
            route={Route.updateChannelsEdit}
            params={{ updateChannelId: updateChannel.id }}
          >
            {updateChannel.name}
          </Link>
        </FormRow>
      </Col>
      <Col lg>
        {maxInProgressUpdates !== undefined && (
          <FormRow
            label={
              <FormattedMessage
                id="forms.UpdateCampaignForm.maxInProgressUpdatesLabel"
                defaultMessage="Max Pending Operations"
              />
            }
          >
            {maxInProgressUpdates}
          </FormRow>
        )}
        {maxErrorsPercentage !== undefined && (
          <FormRow
            label={
              <FormattedMessage
                id="forms.UpdateCampaignForm.maxErrorsPercentageLabel"
                defaultMessage="Max Errors <muted>(%)</muted>"
                values={{
                  muted: (chunks: React.ReactNode) => (
                    <span className="small text-muted">{chunks}</span>
                  ),
                }}
              />
            }
          >
            {maxErrorsPercentage}
          </FormRow>
        )}
        {otaRequestTimeoutSeconds !== undefined && (
          <FormRow
            label={
              <FormattedMessage
                id="forms.UpdateCampaignForm.otaRequestTimeoutSeconds"
                defaultMessage="Request Timeout <muted>(seconds)</muted>"
                values={{
                  muted: (chunks: React.ReactNode) => (
                    <span className="small text-muted">{chunks}</span>
                  ),
                }}
              />
            }
          >
            {otaRequestTimeoutSeconds}
          </FormRow>
        )}
        {otaRequestRetries !== undefined && (
          <FormRow
            label={
              <FormattedMessage
                id="forms.UpdateCampaignForm.otaRequestRetriesLabel"
                defaultMessage="Request Retries"
              />
            }
          >
            {otaRequestRetries}
          </FormRow>
        )}
        {forceDowngrade !== undefined && (
          <FormRow
            label={
              <FormattedMessage
                id="forms.UpdateCampaignForm.forceDowngradeLabel"
                defaultMessage="Force Downgrade"
              />
            }
          >
            <Form.Check checked={forceDowngrade} disabled />
          </FormRow>
        )}
      </Col>
    </Row>
  );
};

export default UpdateCampaign;
