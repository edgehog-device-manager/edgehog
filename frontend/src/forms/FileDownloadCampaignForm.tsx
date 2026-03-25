/*
 * This file is part of Edgehog.
 *
 * Copyright 2026 SECO Mind Srl
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

import type { ReactNode } from "react";
import { FormattedMessage } from "react-intl";
import { graphql, useFragment } from "react-relay/hooks";

import type { FileDownloadCampaignForm_CampaignFragment$key } from "@/api/__generated__/FileDownloadCampaignForm_CampaignFragment.graphql";

import CampaignOutcome from "@/components/CampaignOutcome";
import CampaignStatus from "@/components/CampaignStatus";
import Col from "@/components/Col";
import { SimpleFormRow as FormRow } from "@/components/FormRow";
import Row from "@/components/Row";
import { Link, Route } from "@/Navigation";

const CAMPAIGN_FORM_FRAGMENT = graphql`
  fragment FileDownloadCampaignForm_CampaignFragment on Campaign {
    ...CampaignStatus_CampaignStatusFragment
    ...CampaignOutcome_CampaignOutcomeFragment
    channel {
      id
      name
    }
    campaignMechanism {
      __typename
      ... on FileDownload {
        maxFailurePercentage
        maxInProgressOperations
        requestRetries
        requestTimeoutSeconds
        destinationType
        destination
        ttlSeconds
        fileMode
        userId
        groupId
        file {
          id
          name
          repository {
            id
            name
          }
        }
      }
    }
  }
`;

type FileDownloadCampaignFormProps = {
  campaignRef: FileDownloadCampaignForm_CampaignFragment$key;
};

const FileDownloadCampaignForm = ({
  campaignRef,
}: FileDownloadCampaignFormProps) => {
  const campaign = useFragment(CAMPAIGN_FORM_FRAGMENT, campaignRef);

  const { channel, campaignMechanism } = campaign;

  if (campaignMechanism.__typename !== "FileDownload") {
    return null;
  }

  const { file } = campaignMechanism;

  return (
    <Row>
      <Col lg>
        <FormRow
          label={
            <FormattedMessage
              id="forms.FileDownloadCampaignForm.statusLabel"
              defaultMessage="Status"
            />
          }
        >
          <CampaignStatus campaignRef={campaign} />
        </FormRow>

        <FormRow
          label={
            <FormattedMessage
              id="forms.FileDownloadCampaignForm.outcomeLabel"
              defaultMessage="Outcome"
            />
          }
        >
          <CampaignOutcome campaignRef={campaign} />
        </FormRow>

        <FormRow
          label={
            <FormattedMessage
              id="forms.FileDownloadCampaignForm.channelLabel"
              defaultMessage="Channel"
            />
          }
        >
          <Link route={Route.channelsEdit} params={{ channelId: channel.id }}>
            {channel.name}
          </Link>
        </FormRow>

        {file?.repository && (
          <FormRow
            label={
              <FormattedMessage
                id="forms.FileDownloadCampaignForm.repositoryLabel"
                defaultMessage="Repository"
              />
            }
          >
            <Link
              route={Route.repositoryEdit}
              params={{ repositoryId: file.repository.id }}
            >
              {file.repository.name}
            </Link>
          </FormRow>
        )}

        {file ? (
          <FormRow
            label={
              <FormattedMessage
                id="forms.FileDownloadCampaignForm.fileLabel"
                defaultMessage="File"
              />
            }
          >
            {file.name}
          </FormRow>
        ) : (
          <FormRow
            label={
              <FormattedMessage
                id="forms.FileDownloadCampaignForm.fileLabel"
                defaultMessage="File"
              />
            }
          >
            <div className="d-flex align-content-center fst-italic text-muted">
              <FormattedMessage
                id="forms.FileDownloadCampaignForm.fileDeleted"
                defaultMessage="The file has been deleted"
              />
            </div>
          </FormRow>
        )}

        <FormRow
          label={
            <FormattedMessage
              id="forms.FileDownloadCampaignForm.destinationTypeLabel"
              defaultMessage="Destination"
            />
          }
        >
          {campaignMechanism.destinationType}
        </FormRow>

        {campaignMechanism.destinationType === "FILESYSTEM" && (
          <FormRow
            label={
              <FormattedMessage
                id="forms.FileDownloadCampaignForm.destinationLabel"
                defaultMessage="Destination Path"
              />
            }
          >
            {campaignMechanism.destination}
          </FormRow>
        )}

        <FormRow
          label={
            <FormattedMessage
              id="forms.FileDownloadCampaignForm.ttlLabel"
              defaultMessage="TTL (seconds)"
            />
          }
        >
          {campaignMechanism.ttlSeconds}
        </FormRow>
      </Col>

      <Col lg>
        <FormRow
          label={
            <FormattedMessage
              id="forms.FileDownloadCampaignForm.maxInProgressOperationsLabel"
              defaultMessage="Max Pending Operations"
            />
          }
        >
          {campaignMechanism.maxInProgressOperations}
        </FormRow>

        <FormRow
          label={
            <FormattedMessage
              id="forms.FileDownloadCampaignForm.maxFailurePercentageLabel"
              defaultMessage="Max Failures <muted>(%)</muted>"
              values={{
                muted: (chunks: ReactNode) => (
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
              id="forms.FileDownloadCampaignForm.requestTimeoutSecondsLabel"
              defaultMessage="Request Timeout <muted>(seconds)</muted>"
              values={{
                muted: (chunks: ReactNode) => (
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
              id="forms.FileDownloadCampaignForm.requestRetriesLabel"
              defaultMessage="Request Retries"
            />
          }
        >
          {campaignMechanism.requestRetries}
        </FormRow>

        {campaignMechanism.fileMode != 0 && (
          <FormRow
            label={
              <FormattedMessage
                id="forms.FileDownloadCampaignForm.fileModeLabel"
                defaultMessage="File Mode"
              />
            }
          >
            {campaignMechanism.fileMode}
          </FormRow>
        )}

        {campaignMechanism.userId != -1 && (
          <FormRow
            label={
              <FormattedMessage
                id="forms.FileDownloadCampaignForm.userIdLabel"
                defaultMessage="User ID"
              />
            }
          >
            {campaignMechanism.userId}
          </FormRow>
        )}

        {campaignMechanism.groupId != -1 && (
          <FormRow
            label={
              <FormattedMessage
                id="forms.FileDownloadCampaignForm.groupIdLabel"
                defaultMessage="Group ID"
              />
            }
          >
            {campaignMechanism.groupId}
          </FormRow>
        )}
      </Col>
    </Row>
  );
};

export default FileDownloadCampaignForm;
