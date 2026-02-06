/*
 * This file is part of Edgehog.
 *
 * Copyright 2023 - 2026 SECO Mind Srl
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
  UpdateCampaignForm_CampaignFragment$data,
  UpdateCampaignForm_CampaignFragment$key,
} from "@/api/__generated__/UpdateCampaignForm_CampaignFragment.graphql";

import Col from "@/components/Col";
import Form from "@/components/Form";
import Row from "@/components/Row";
import CampaignOutcome from "@/components/CampaignOutcome";
import CampaignStatus from "@/components/CampaignStatus";
import { SimpleFormRow as FormRow } from "@/components/FormRow";
import { Link, Route } from "@/Navigation";

// We use graphql fields below in columns configuration
/* eslint-disable relay/unused-fields */
const CAMPAIGN_FORM_FRAGMENT = graphql`
  fragment UpdateCampaignForm_CampaignFragment on Campaign {
    ...CampaignStatus_CampaignStatusFragment
    ...CampaignOutcome_CampaignOutcomeFragment
    channel {
      id
      name
    }
    campaignMechanism {
      __typename
      ... on FirmwareUpgrade {
        maxFailurePercentage
        maxInProgressOperations
        requestRetries
        requestTimeoutSeconds
        forceDowngrade
        baseImage {
          id
          name
          baseImageCollection {
            id
            name
          }
        }
      }
    }
  }
`;

type CampaignMechanismColProps = {
  campaignMechanism: UpdateCampaignForm_CampaignFragment$data["campaignMechanism"];
};

const CampaignMechanismCol = ({
  campaignMechanism,
}: CampaignMechanismColProps) => {
  if (campaignMechanism.__typename !== "FirmwareUpgrade") {
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
        {campaignMechanism.maxInProgressOperations}
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
        {campaignMechanism.maxFailurePercentage}
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
        {campaignMechanism.requestTimeoutSeconds}
      </FormRow>
      <FormRow
        label={
          <FormattedMessage
            id="forms.UpdateCampaignForm.rolloutMechanism.otaRequestRetriesLabel"
            defaultMessage="Request Retries"
          />
        }
      >
        {campaignMechanism.requestRetries}
      </FormRow>
      <FormRow
        label={
          <FormattedMessage
            id="forms.UpdateCampaignForm.rolloutMechanism.forceDowngradeLabel"
            defaultMessage="Force Downgrade"
          />
        }
      >
        <Form.Check checked={campaignMechanism.forceDowngrade} disabled />
      </FormRow>
    </Col>
  );
};

type UpdateCampaignProps = {
  campaignRef: UpdateCampaignForm_CampaignFragment$key;
};

const UpdateCampaign = ({ campaignRef }: UpdateCampaignProps) => {
  const campaign = useFragment(CAMPAIGN_FORM_FRAGMENT, campaignRef);

  const { channel, campaignMechanism } = campaign;

  if (campaignMechanism.__typename !== "FirmwareUpgrade") {
    return null;
  }

  const { baseImage } = campaignMechanism;

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
          <CampaignStatus campaignRef={campaign} />
        </FormRow>
        <FormRow
          label={
            <FormattedMessage
              id="forms.UpdateCampaignForm.outcomeLabel"
              defaultMessage="Outcome"
            />
          }
        >
          <CampaignOutcome campaignRef={campaign} />
        </FormRow>
        {baseImage ? (
          <>
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
                params={{
                  baseImageCollectionId: baseImage.baseImageCollection.id,
                }}
              >
                {baseImage.baseImageCollection.name}
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
                  baseImageCollectionId: baseImage.baseImageCollection.id,
                  baseImageId: baseImage.id,
                }}
              >
                {baseImage.name}
              </Link>
            </FormRow>
          </>
        ) : (
          <FormRow
            label={
              <FormattedMessage
                id="forms.UpdateCampaignForm.baseImageLabel"
                defaultMessage="Base Image"
              />
            }
          >
            <div className="d-flex align-content-center fst-italic text-muted">
              <FormattedMessage
                id="forms.UpdateCampaignForm.baseImageDeleted"
                defaultMessage="The Base Image has been deleted"
              />
            </div>
          </FormRow>
        )}
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
      <CampaignMechanismCol campaignMechanism={campaignMechanism} />
    </Row>
  );
};

export default UpdateCampaign;
