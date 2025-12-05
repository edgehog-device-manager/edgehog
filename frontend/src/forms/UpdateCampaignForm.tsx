/*
 * This file is part of Edgehog.
 *
 * Copyright 2023-2025 SECO Mind Srl
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
  UpdateCampaignForm_UpdateCampaignFragment$data,
  UpdateCampaignForm_UpdateCampaignFragment$key,
} from "@/api/__generated__/UpdateCampaignForm_UpdateCampaignFragment.graphql";

import Col from "@/components/Col";
import Form from "@/components/Form";
import Row from "@/components/Row";
import UpdateCampaignOutcome from "@/components/UpdateCampaignOutcome";
import UpdateCampaignStatus from "@/components/UpdateCampaignStatus";
import { SimpleFormRow as FormRow } from "@/components/FormRow";
import { Link, Route } from "@/Navigation";

// We use graphql fields below in columns configuration
/* eslint-disable relay/unused-fields */
const UPDATE_CAMPAIGN_FORM_FRAGMENT = graphql`
  fragment UpdateCampaignForm_UpdateCampaignFragment on UpdateCampaign {
    ...UpdateCampaignStatus_UpdateCampaignStatusFragment
    ...UpdateCampaignOutcome_UpdateCampaignOutcomeFragment
    baseImage {
      id
      name
      baseImageCollection {
        id
        name
      }
    }
    channel {
      id
      name
    }
    rolloutMechanism {
      __typename
      ... on PushRollout {
        maxFailurePercentage
        maxInProgressUpdates
        otaRequestRetries
        otaRequestTimeoutSeconds
        forceDowngrade
      }
    }
  }
`;

type RolloutMechanismColProps = {
  rolloutMechanism: UpdateCampaignForm_UpdateCampaignFragment$data["rolloutMechanism"];
};
const RolloutMechanismCol = ({
  rolloutMechanism,
}: RolloutMechanismColProps) => {
  if (rolloutMechanism.__typename !== "PushRollout") {
    return null;
  }

  return (
    <Col lg>
      <FormRow
        label={
          <FormattedMessage
            id="forms.UpdateCampaignForm.rolloutMechanism.maxInProgressUpdatesLabel"
            defaultMessage="Max Pending Operations"
          />
        }
      >
        {rolloutMechanism.maxInProgressUpdates}
      </FormRow>
      <FormRow
        label={
          <FormattedMessage
            id="forms.UpdateCampaignForm.rolloutMechanism.maxFailurePercentageLabel"
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
            id="forms.UpdateCampaignForm.rolloutMechanism.otaRequestTimeoutSeconds"
            defaultMessage="Request Timeout <muted>(seconds)</muted>"
            values={{
              muted: (chunks: React.ReactNode) => (
                <span className="small text-muted">{chunks}</span>
              ),
            }}
          />
        }
      >
        {rolloutMechanism.otaRequestTimeoutSeconds}
      </FormRow>
      <FormRow
        label={
          <FormattedMessage
            id="forms.UpdateCampaignForm.rolloutMechanism.otaRequestRetriesLabel"
            defaultMessage="Request Retries"
          />
        }
      >
        {rolloutMechanism.otaRequestRetries}
      </FormRow>
      <FormRow
        label={
          <FormattedMessage
            id="forms.UpdateCampaignForm.rolloutMechanism.forceDowngradeLabel"
            defaultMessage="Force Downgrade"
          />
        }
      >
        <Form.Check checked={rolloutMechanism.forceDowngrade} disabled />
      </FormRow>
    </Col>
  );
};

type UpdateCampaignProps = {
  updateCampaignRef: UpdateCampaignForm_UpdateCampaignFragment$key;
};

const UpdateCampaign = ({ updateCampaignRef }: UpdateCampaignProps) => {
  const updateCampaign = useFragment(
    UPDATE_CAMPAIGN_FORM_FRAGMENT,
    updateCampaignRef,
  );

  const { baseImage, channel, rolloutMechanism } = updateCampaign;
  const { baseImageCollection } = baseImage;
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
            {baseImage.name}
          </Link>
        </FormRow>
        <FormRow
          label={
            <FormattedMessage
              id="forms.UpdateCampaignForm.channelLabel"
              defaultMessage="Channel"
            />
          }
        >
          <Link route={Route.channelsEdit} params={{ channelId: channel.id }}>
            {channel.name}
          </Link>
        </FormRow>
      </Col>
      <RolloutMechanismCol rolloutMechanism={rolloutMechanism} />
    </Row>
  );
};

export default UpdateCampaign;
