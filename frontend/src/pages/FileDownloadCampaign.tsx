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
import { Suspense, useCallback, useEffect, useState } from "react";
import Countdown, { type CountdownRenderProps } from "react-countdown";
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
import { useParams } from "react-router-dom";
import { Card } from "react-bootstrap";

import type {
  FileDownloadCampaign_getCampaign_Query,
  FileDownloadCampaign_getCampaign_Query$data,
} from "@/api/__generated__/FileDownloadCampaign_getCampaign_Query.graphql";
import type { FileDownloadCampaign_pauseCampaign_Mutation } from "@/api/__generated__/FileDownloadCampaign_pauseCampaign_Mutation.graphql";
import type { FileDownloadCampaign_resumeCampaign_Mutation } from "@/api/__generated__/FileDownloadCampaign_resumeCampaign_Mutation.graphql";

import Alert from "@/components/Alert";
import Button from "@/components/Button";
import CampaignStatsChart from "@/components/CampaignStatsChart";
import Center from "@/components/Center";
import Col from "@/components/Col";
import FileDownloadTargetsTabs from "@/components/FileDownloadTargetsTabs";
import Icon from "@/components/Icon";
import Page from "@/components/Page";
import Result from "@/components/Result";
import Row from "@/components/Row";
import Spinner from "@/components/Spinner";
import { RECORDS_TO_LOAD_FIRST } from "@/constants";
import FileDownloadCampaignForm from "@/forms/FileDownloadCampaignForm";
import { Link, Route } from "@/Navigation";

const GET_CAMPAIGN_QUERY = graphql`
  query FileDownloadCampaign_getCampaign_Query(
    $fileDownloadCampaignId: ID!
    $first: Int!
    $after: String
    $filter: CampaignTargetFilterInput = { status: { eq: SUCCESSFUL } }
  ) {
    campaign(id: $fileDownloadCampaignId) {
      name
      status
      scheduledAtTimestamp
      ...FileDownloadCampaignForm_CampaignFragment
      ...CampaignStatsChart_CampaignStatsChartFragment
      ...FileDownloadTargetsTabs_FileDownloadTargetsFragment
        @arguments(first: $first, after: $after, filter: $filter)
    }
  }
`;

const PAUSE_CAMPAIGN_MUTATION = graphql`
  mutation FileDownloadCampaign_pauseCampaign_Mutation($id: ID!) {
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
  mutation FileDownloadCampaign_resumeCampaign_Mutation($id: ID!) {
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
  subscription FileDownloadCampaign_campaignUpdated_Subscription($id: ID!) {
    campaign(id: $id) {
      updated {
        id
        status
        outcome
        scheduledAtTimestamp
        idleTargetCount
        inProgressTargetCount
        failedTargetCount
        successfulTargetCount
      }
    }
  }
`;

const CAMPAIGN_TARGETS_UPDATED_SUBSCRIPTION = graphql`
  subscription FileDownloadCampaign_campaignTargetsUpdated_Subscription(
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
        fileDownloadRequest {
          status
          progressPercentage
          responseCode
          responseMessage
        }
      }
    }
  }
`;

const renderCountdown = ({
  completed,
  days,
  hours,
  minutes,
  seconds,
}: CountdownRenderProps) => {
  if (completed) {
    return null;
  }

  const duration = [
    days > 0 ? `${days}d` : null,
    hours > 0 || days > 0 ? `${hours}h` : null,
    minutes > 0 || hours > 0 || days > 0 ? `${minutes}m` : null,
    `${seconds}s`,
  ].filter(Boolean);

  return (
    <strong>
      <FormattedMessage
        id="pages.FileDownloadCampaign.scheduledStartsIn"
        defaultMessage="Starts in {duration}"
        values={{ duration: duration.join(" ") }}
      />
    </strong>
  );
};

type CampaignActionsProps = {
  fileDownloadCampaignId: string;
  campaignData: FileDownloadCampaign_getCampaign_Query$data["campaign"];
  setErrorFeedback: (errorMessages: ReactNode) => void;
};

const CampaignActions = ({
  fileDownloadCampaignId,
  campaignData,
  setErrorFeedback,
}: CampaignActionsProps) => {
  const status = campaignData?.status;

  const [pauseCampaign, isPausing] =
    useMutation<FileDownloadCampaign_pauseCampaign_Mutation>(
      PAUSE_CAMPAIGN_MUTATION,
    );

  const [resumeCampaign, isResuming] =
    useMutation<FileDownloadCampaign_resumeCampaign_Mutation>(
      RESUME_CAMPAIGN_MUTATION,
    );

  const handlePauseCampaign = useCallback(() => {
    pauseCampaign({
      variables: { id: fileDownloadCampaignId },
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
            id="pages.FileDownloadCampaign.pauseErrorFeedback"
            defaultMessage="Could not pause the campaign, please try again."
          />,
        );
      },
    });
  }, [fileDownloadCampaignId, pauseCampaign, setErrorFeedback]);

  const handleResumeCampaign = useCallback(() => {
    resumeCampaign({
      variables: { id: fileDownloadCampaignId },
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
            id="pages.FileDownloadCampaign.resumeErrorFeedback"
            defaultMessage="Could not resume the campaign, please try again."
          />,
        );
      },
    });
  }, [fileDownloadCampaignId, resumeCampaign, setErrorFeedback]);

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
          id="pages.FileDownloadCampaign.resumeButton"
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
          id="pages.FileDownloadCampaign.pauseButton"
          defaultMessage="Pause"
        />
      </Button>
    );
  }

  return null;
};

type FileDownloadCampaignContentProps = {
  fileDownloadCampaignId: string;
  getCampaignQuery: PreloadedQuery<FileDownloadCampaign_getCampaign_Query>;
};

// TODO: There is a lot of duplicate code between all the campaign pages,
// consider refactoring to extract common components and logic

const FileDownloadCampaignContent = ({
  fileDownloadCampaignId,
  getCampaignQuery,
}: FileDownloadCampaignContentProps) => {
  const [errorFeedback, setErrorFeedback] = useState<ReactNode>(null);

  const { campaign } =
    usePreloadedQuery<FileDownloadCampaign_getCampaign_Query>(
      GET_CAMPAIGN_QUERY,
      getCampaignQuery,
    );

  const scheduledDate = campaign?.scheduledAtTimestamp
    ? new Date(campaign.scheduledAtTimestamp)
    : null;

  const isValidScheduledDate =
    scheduledDate && !Number.isNaN(scheduledDate.getTime());

  const [now] = useState(() => Date.now());

  const shouldShowScheduledAlert =
    !!campaign?.scheduledAtTimestamp &&
    (!isValidScheduledDate || scheduledDate.getTime() > now);

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
            id="pages.FileDownloadCampaign.notFound.title"
            defaultMessage="File Download Campaign not found."
          />
        }
      >
        <Link route={Route.fileDownloadCampaigns}>
          <FormattedMessage
            id="pages.FileDownloadCampaign.notFound.message"
            defaultMessage="Return to the File Download Campaign list."
          />
        </Link>
      </Result.NotFound>
    );
  }

  return (
    <Page>
      <Page.Header title={campaign.name}>
        <CampaignActions
          fileDownloadCampaignId={fileDownloadCampaignId}
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

        <Alert show={shouldShowScheduledAlert} variant="warning">
          <div>
            <strong>
              <FormattedMessage
                id="pages.FileDownloadCampaign.scheduledFor"
                defaultMessage="Scheduled for: {scheduledDate}"
                values={{ scheduledDate: formattedScheduledDate }}
              />
            </strong>
          </div>
          {isValidScheduledDate && (
            <div>
              <Countdown
                date={scheduledDate.getTime()}
                overtime
                renderer={renderCountdown}
              />
            </div>
          )}
        </Alert>
        <Card className="h-100 border-0 p-3 shadow-sm mb-3">
          <Row>
            <Col lg={9}>
              <FileDownloadCampaignForm campaignRef={campaign} />
            </Col>
            <Col lg={3}>
              <CampaignStatsChart campaignRef={campaign} />
            </Col>
          </Row>
        </Card>
        <Card className="gap-2 border-0 shadow-sm flex-grow-1 p-4">
          <FileDownloadTargetsTabs campaignRef={campaign} />
        </Card>
      </Page.Main>
    </Page>
  );
};

const FileDownloadCampaignPage = () => {
  const { fileDownloadCampaignId = "" } = useParams();

  const [getCampaignQuery, getCampaign] =
    useQueryLoader<FileDownloadCampaign_getCampaign_Query>(GET_CAMPAIGN_QUERY);

  const fetchCampaign = useCallback(() => {
    getCampaign(
      {
        fileDownloadCampaignId,
        first: RECORDS_TO_LOAD_FIRST,
      },
      { fetchPolicy: "network-only" },
    );
  }, [getCampaign, fileDownloadCampaignId]);

  useEffect(fetchCampaign, [fetchCampaign]);

  useSubscription({
    subscription: CAMPAIGN_UPDATE_SUBSCRIPTION,
    variables: { id: fileDownloadCampaignId },
  });

  useSubscription({
    subscription: CAMPAIGN_TARGETS_UPDATED_SUBSCRIPTION,
    variables: { campaignId: fileDownloadCampaignId },
    updater: (store) => {
      const payload = store.getRootField("campaignTargetsByCampaign");
      const node = payload?.getLinkedRecord("updated");
      if (!node) return;

      const root = store.getRoot();
      const campaignRoot = root.getLinkedRecord("campaign", {
        id: fileDownloadCampaignId,
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
          "FileDownloadTargetsTabs_campaignTargets",
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
          <FileDownloadCampaignContent
            fileDownloadCampaignId={fileDownloadCampaignId}
            getCampaignQuery={getCampaignQuery}
          />
        )}
      </ErrorBoundary>
    </Suspense>
  );
};

export default FileDownloadCampaignPage;
