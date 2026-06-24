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

import { Suspense, useCallback, useEffect, useState } from "react";
import { ErrorBoundary } from "react-error-boundary";
import { FormattedDate, FormattedMessage } from "react-intl";
import type { PreloadedQuery } from "react-relay/hooks";
import {
  ConnectionHandler,
  graphql,
  useMutation,
  usePreloadedQuery,
  useQueryLoader,
  useSubscription,
} from "react-relay/hooks";
import { useNavigate, useParams } from "react-router-dom";

import type {
  UpdateCampaign_getCampaign_Query,
  UpdateCampaign_getCampaign_Query$data,
} from "@/api/__generated__/UpdateCampaign_getCampaign_Query.graphql";
import type { UpdateCampaign_pauseCampaign_Mutation } from "@/api/__generated__/UpdateCampaign_pauseCampaign_Mutation.graphql";
import type { UpdateCampaign_resumeCampaign_Mutation } from "@/api/__generated__/UpdateCampaign_resumeCampaign_Mutation.graphql";

import Alert from "@/components/Alert";
import Button from "@/components/Button";
import CampaignScheduledAlert from "@/components/CampaignScheduledAlert";
import CampaignStatsChart from "@/components/CampaignStatsChart";
import Center from "@/components/Center";
import Col from "@/components/Col";
import DeleteCampaignModal from "@/components/DeleteCampaignModal";
import Icon from "@/components/Icon";
import Page from "@/components/Page";
import Result from "@/components/Result";
import Row from "@/components/Row";
import Spinner from "@/components/Spinner";
import UpdateTargetsTabs from "@/components/UpdateTargetsTabs";
import { RECORDS_TO_LOAD_FIRST } from "@/constants";
import UpdateCampaignForm from "@/forms/UpdateCampaignForm";
import { Link, Route } from "@/Navigation";
import EditUpdateCampaignModal from "@/components/EditUpdateCampaignModal";

const GET_CAMPAIGN_QUERY = graphql`
  query UpdateCampaign_getCampaign_Query(
    $campaignId: ID!
    $first: Int!
    $after: String
    $filter: CampaignTargetFilterInput = { status: { eq: SUCCESSFUL } }
  ) {
    campaign(id: $campaignId) {
      id
      name
      status
      scheduledAtTimestamp
      campaignMechanism {
        ... on FirmwareUpgrade {
          maxFailurePercentage
          maxInProgressOperations
          requestRetries
          requestTimeoutSeconds
          forceDowngrade
          baseImage {
            id
            name
            version
            baseImageCollection {
              id
              name
            }
          }
        }
      }
      ...UpdateCampaignForm_CampaignFragment
      ...CampaignStatsChart_CampaignStatsChartFragment
      ...UpdateTargetsTabs_UpdateTargetsFragment
        @arguments(first: $first, after: $after, filter: $filter)
    }
    ...EditUpdateCampaignModal_BaseImageCollOptionsFragment
  }
`;

const PAUSE_CAMPAIGN_MUTATION = graphql`
  mutation UpdateCampaign_pauseCampaign_Mutation($id: ID!) {
    pauseCampaign(id: $id) {
      result {
        id
        status
      }
      errors {
        message
      }
    }
  }
`;

const RESUME_CAMPAIGN_MUTATION = graphql`
  mutation UpdateCampaign_resumeCampaign_Mutation($id: ID!) {
    resumeCampaign(id: $id) {
      result {
        id
        status
      }
      errors {
        message
      }
    }
  }
`;

const CAMPAIGN_UPDATE_SUBSCRIPTION = graphql`
  subscription UpdateCampaign_campaignUpdated_Subscription($id: ID!) {
    campaign(id: $id) {
      updated {
        id
        name
        status
        outcome
        scheduledAtTimestamp
        idleTargetCount
        inProgressTargetCount
        failedTargetCount
        successfulTargetCount
        campaignMechanism {
          ... on FirmwareUpgrade {
            maxFailurePercentage
            maxInProgressOperations
            requestRetries
            requestTimeoutSeconds
            baseImage {
              name
              version
              baseImageCollection {
                name
              }
            }
          }
        }
      }
    }
  }
`;

const CAMPAIGN_TARGETS_UPDATED_SUBSCRIPTION = graphql`
  subscription UpdateCampaign_campaignTargetsUpdated_Subscription(
    $campaignId: ID!
  ) {
    campaignTargetsByCampaign(campaignId: $campaignId) {
      updated {
        id
        device {
          id
          name
        }
        status
        retryCount
        latestAttempt
        completionTimestamp
        otaOperation {
          status
          statusProgress
          statusCode
          message
        }
      }
    }
  }
`;

type CampaignActionsProps = {
  updateCampaignId: string;
  campaignData: UpdateCampaign_getCampaign_Query$data["campaign"];
  setErrorFeedback: (errorMessages: React.ReactNode) => void;
};

const CampaignActions = ({
  updateCampaignId,
  campaignData,
  setErrorFeedback,
}: CampaignActionsProps) => {
  const status = campaignData?.status;

  const [pauseCampaign, isPausing] =
    useMutation<UpdateCampaign_pauseCampaign_Mutation>(PAUSE_CAMPAIGN_MUTATION);

  const [resumeCampaign, isResuming] =
    useMutation<UpdateCampaign_resumeCampaign_Mutation>(
      RESUME_CAMPAIGN_MUTATION,
    );

  const handlePauseCampaign = useCallback(() => {
    pauseCampaign({
      variables: { id: updateCampaignId },
      onCompleted(_data, errors) {
        if (!errors || errors.length === 0 || errors[0].code === "not_found") {
          setErrorFeedback(null);
          return;
        }

        const errorFeedback = errors
          .map(({ fields, message }) =>
            fields.length ? `${fields.join(" ")} ${message}` : message,
          )
          .join(". \n");
        setErrorFeedback(errorFeedback);
      },
      onError() {
        setErrorFeedback(
          <FormattedMessage
            id="pages.UpdateCampaign.pauseErrorFeedback"
            defaultMessage="Could not pause the campaign, please try again."
          />,
        );
      },
    });
  }, [updateCampaignId, pauseCampaign, setErrorFeedback]);

  const handleResumeCampaign = useCallback(() => {
    resumeCampaign({
      variables: { id: updateCampaignId },
      onCompleted(_data, errors) {
        if (!errors || errors.length === 0 || errors[0].code === "not_found") {
          setErrorFeedback(null);
          return;
        }

        const errorFeedback = errors
          .map(({ fields, message }) =>
            fields.length ? `${fields.join(" ")} ${message}` : message,
          )
          .join(". \n");
        setErrorFeedback(errorFeedback);
      },
      onError() {
        setErrorFeedback(
          <FormattedMessage
            id="pages.UpdateCampaign.resumeErrorFeedback"
            defaultMessage="Could not resume the campaign, please try again."
          />,
        );
      },
    });
  }, [updateCampaignId, resumeCampaign, setErrorFeedback]);

  if (status === "PAUSED" || status === "PAUSING") {
    return (
      <Button
        variant="success"
        size="sm"
        onClick={handleResumeCampaign}
        disabled={isResuming || status === "PAUSING"}
        className="ms-2"
        title="Resume Campaign"
      >
        <Icon icon="play" className="me-2" />
        <FormattedMessage
          id="pages.UpdateCampaign.resumeButton"
          defaultMessage="Resume"
        />
      </Button>
    );
  }

  if (status === "IN_PROGRESS") {
    return (
      <Button
        variant="warning"
        size="sm"
        onClick={handlePauseCampaign}
        disabled={isPausing}
        className="ms-2"
        title="Pause Campaign"
      >
        <Icon icon="pause" className="me-2" />
        <FormattedMessage
          id="pages.UpdateCampaign.pauseButton"
          defaultMessage="Pause"
        />
      </Button>
    );
  }

  return null;
};

type UpdateCampaignContentProps = {
  updateCampaignId: string;
  getCampaignQuery: PreloadedQuery<UpdateCampaign_getCampaign_Query>;
};

// TODO: There is a lot of duplicate code between all the campaign pages,
// consider refactoring to extract common components and logic

const UpdateCampaignContent = ({
  updateCampaignId,
  getCampaignQuery,
}: UpdateCampaignContentProps) => {
  const navigate = useNavigate();

  const [errorFeedback, setErrorFeedback] = useState<React.ReactNode>(null);
  const [showEditModal, setShowEditModal] = useState(false);
  const [showDeleteModal, setShowDeleteModal] = useState(false);

  const queryData = usePreloadedQuery(GET_CAMPAIGN_QUERY, getCampaignQuery);
  const { campaign } = queryData;

  const scheduledDate = campaign?.scheduledAtTimestamp
    ? new Date(campaign.scheduledAtTimestamp)
    : null;

  const isValidScheduledDate =
    scheduledDate && !Number.isNaN(scheduledDate.getTime());

  const shouldShowScheduledAlert = campaign?.status === "SCHEDULED";

  const formattedScheduledDate = isValidScheduledDate ? (
    <FormattedDate value={scheduledDate} dateStyle="medium" timeStyle="short" />
  ) : (
    campaign?.scheduledAtTimestamp
  );

  if (!campaign) {
    return (
      <Result.NotFound
        title={
          <FormattedMessage
            id="pages.UpdateCampaign.updateCampaignNotFound.title"
            defaultMessage="Update Campaign not found."
          />
        }
      >
        <Link route={Route.updateCampaigns}>
          <FormattedMessage
            id="pages.UpdateCampaign.updateCampaignNotFound.message"
            defaultMessage="Return to the Update Campaign list."
          />
        </Link>
      </Result.NotFound>
    );
  }

  return (
    <Page>
      <Page.Header title={campaign.name}>
        <CampaignActions
          updateCampaignId={updateCampaignId}
          campaignData={campaign}
          setErrorFeedback={setErrorFeedback}
        />
      </Page.Header>
      <Page.Main>
        <Alert
          show={!!errorFeedback}
          variant="danger"
          onClose={() => setErrorFeedback(null)}
          dismissible
        >
          {errorFeedback}
        </Alert>

        <CampaignScheduledAlert
          show={shouldShowScheduledAlert}
          scheduledAt={campaign?.scheduledAtTimestamp}
          isValidScheduledDate={!!isValidScheduledDate}
          formattedScheduledDate={formattedScheduledDate}
          onEdit={() => setShowEditModal(true)}
          onDelete={() => setShowDeleteModal(true)}
        />

        <Row>
          <Col lg={9}>
            <UpdateCampaignForm campaignRef={campaign} />
          </Col>
          <Col lg={3}>
            <CampaignStatsChart campaignRef={campaign} />
          </Col>
        </Row>
        <hr className="bg-secondary border-2 border-top border-secondary" />
        <UpdateTargetsTabs campaignRef={campaign} />

        {showDeleteModal && (
          <DeleteCampaignModal
            campaignToDelete={campaign}
            onCancel={() => setShowDeleteModal(false)}
            onSuccess={() => {
              setShowDeleteModal(false);
              navigate(Route.fileDownloadCampaigns);
            }}
            setErrorFeedback={setErrorFeedback}
          />
        )}

        {showEditModal && (
          <EditUpdateCampaignModal
            campaignToUpdate={campaign}
            campaignOptionsRef={queryData}
            onCancel={() => setShowEditModal(false)}
            onSuccess={() => {
              setShowEditModal(false);
              // Optional: Show a success toast/alert
            }}
            setErrorFeedback={setErrorFeedback}
          />
        )}
      </Page.Main>
    </Page>
  );
};

const UpdateCampaignPage = () => {
  const { updateCampaignId = "" } = useParams();

  const [getCampaignQuery, getCampaign] =
    useQueryLoader<UpdateCampaign_getCampaign_Query>(GET_CAMPAIGN_QUERY);

  const fetchCampaign = useCallback(() => {
    getCampaign(
      { campaignId: updateCampaignId, first: RECORDS_TO_LOAD_FIRST },
      { fetchPolicy: "network-only" },
    );
  }, [getCampaign, updateCampaignId]);

  useEffect(fetchCampaign, [fetchCampaign]);

  useSubscription({
    subscription: CAMPAIGN_UPDATE_SUBSCRIPTION,
    variables: { id: updateCampaignId },
  });

  useSubscription({
    subscription: CAMPAIGN_TARGETS_UPDATED_SUBSCRIPTION,
    variables: { campaignId: updateCampaignId },
    updater: (store) => {
      const payload = store.getRootField("campaignTargetsByCampaign");
      const node = payload?.getLinkedRecord("updated");
      if (!node) return;

      const root = store.getRoot();
      const campaignRoot = root.getLinkedRecord("campaign", {
        id: updateCampaignId,
      });
      if (!campaignRoot) return;

      const nodeStatus = node.getValue("status");

      const STATUS_CONFIGS = [
        {
          status: "SUCCESSFUL",
          filters: { filter: { status: { eq: "SUCCESSFUL" } } },
        },
        {
          status: "IN_PROGRESS",
          filters: { filter: { status: { eq: "IN_PROGRESS" } } },
        },
        {
          status: "IDLE",
          filters: { filter: { status: { eq: "IDLE" } } },
        },
        {
          status: "FAILED",
          filters: { filter: { status: { eq: "FAILED" } } },
        },
      ];

      for (const { status, filters } of STATUS_CONFIGS) {
        const connection = ConnectionHandler.getConnection(
          campaignRoot,
          "UpdateTargetsTabs_campaignTargets",
          filters,
        );
        if (!connection) continue;

        const existingEdges = connection.getLinkedRecords("edges") ?? [];

        const filteredEdges = existingEdges.filter((edge) => {
          const edgeNode = edge.getLinkedRecord("node");
          return edgeNode?.getDataID() !== node.getDataID();
        });

        if (nodeStatus !== status) {
          connection.setLinkedRecords(filteredEdges, "edges");
          continue;
        }

        const newEdge = ConnectionHandler.createEdge(
          store,
          connection,
          node,
          "CampaignTargetEdge",
        );

        connection.setLinkedRecords([newEdge, ...filteredEdges], "edges");
      }
    },
  });

  return (
    <Suspense
      fallback={
        <Center data-testid="page-loading">
          <Spinner />
        </Center>
      }
    >
      <ErrorBoundary
        FallbackComponent={(props) => (
          <Center data-testid="page-error">
            <Page.LoadingError onRetry={props.resetErrorBoundary} />
          </Center>
        )}
        onReset={fetchCampaign}
      >
        {getCampaignQuery && (
          <UpdateCampaignContent
            updateCampaignId={updateCampaignId}
            getCampaignQuery={getCampaignQuery}
          />
        )}
      </ErrorBoundary>
    </Suspense>
  );
};

export default UpdateCampaignPage;
