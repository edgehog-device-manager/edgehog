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

import { Suspense, useCallback, useEffect, useState } from "react";
import { ErrorBoundary } from "react-error-boundary";
import { FormattedMessage } from "react-intl";
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

import type {
  DeploymentCampaign_getCampaign_Query,
  DeploymentCampaign_getCampaign_Query$data,
} from "@/api/__generated__/DeploymentCampaign_getCampaign_Query.graphql";
import type { DeploymentCampaign_pauseCampaign_Mutation } from "@/api/__generated__/DeploymentCampaign_pauseCampaign_Mutation.graphql";
import type { DeploymentCampaign_resumeCampaign_Mutation } from "@/api/__generated__/DeploymentCampaign_resumeCampaign_Mutation.graphql";

import Alert from "@/components/Alert";
import Button from "@/components/Button";
import CampaignStatsChart from "@/components/CampaignStatsChart";
import Center from "@/components/Center";
import Col from "@/components/Col";
import DeploymentTargetsTabs from "@/components/DeploymentTargetsTabs";
import Icon from "@/components/Icon";
import Page from "@/components/Page";
import Result from "@/components/Result";
import Row from "@/components/Row";
import Spinner from "@/components/Spinner";
import { RECORDS_TO_LOAD_FIRST } from "@/constants";
import DeploymentCampaignForm from "@/forms/DeploymentCampaignForm";
import { Link, Route } from "@/Navigation";

const GET_CAMPAIGN_QUERY = graphql`
  query DeploymentCampaign_getCampaign_Query(
    $deploymentCampaignId: ID!
    $first: Int!
    $after: String
    $filter: CampaignTargetFilterInput = { status: { eq: SUCCESSFUL } }
  ) {
    campaign(id: $deploymentCampaignId) {
      name
      status
      ...DeploymentCampaignForm_CampaignFragment
      ...CampaignStatsChart_CampaignStatsChartFragment
      ...DeploymentTargetsTabs_DeploymentTargetsFragment
        @arguments(first: $first, after: $after, filter: $filter)
    }
  }
`;

const PAUSE_CAMPAIGN_MUTATION = graphql`
  mutation DeploymentCampaign_pauseCampaign_Mutation($id: ID!) {
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
  mutation DeploymentCampaign_resumeCampaign_Mutation($id: ID!) {
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
  subscription DeploymentCampaign_campaignUpdated_Subscription($id: ID!) {
    campaign(id: $id) {
      updated {
        id
        status
        outcome
        idleTargetCount
        inProgressTargetCount
        failedTargetCount
        successfulTargetCount
        campaignTargets {
          edges {
            node {
              id
              device {
                id
                name
              }
              status
              retryCount
              latestAttempt
              completionTimestamp
              deployment {
                state
                isReady
                events(
                  filter: { type: { eq: ERROR } }
                  sort: [{ field: INSERTED_AT, order: DESC }]
                  first: 1
                ) {
                  edges {
                    node {
                      message
                      type
                      insertedAt
                      addInfo
                    }
                  }
                }
              }
            }
          }
        }
      }
    }
  }
`;

type CampaignActionsProps = {
  deploymentCampaignId: string;
  campaignData: DeploymentCampaign_getCampaign_Query$data["campaign"];
  setErrorFeedback: (errorMessages: React.ReactNode) => void;
};

const CampaignActions = ({
  deploymentCampaignId,
  campaignData,
  setErrorFeedback,
}: CampaignActionsProps) => {
  const status = campaignData?.status;

  const [pauseCampaign, isPausing] =
    useMutation<DeploymentCampaign_pauseCampaign_Mutation>(
      PAUSE_CAMPAIGN_MUTATION,
    );

  const [resumeCampaign, isResuming] =
    useMutation<DeploymentCampaign_resumeCampaign_Mutation>(
      RESUME_CAMPAIGN_MUTATION,
    );

  const handlePauseCampaign = useCallback(() => {
    pauseCampaign({
      variables: { id: deploymentCampaignId },
      onCompleted(data, errors) {
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
            id="components.DeploymentCampaign.pauseErrorFeedback"
            defaultMessage="Could not pause the campaign, please try again."
          />,
        );
      },
    });
  }, [deploymentCampaignId, pauseCampaign, setErrorFeedback]);

  const handleResumeCampaign = useCallback(() => {
    resumeCampaign({
      variables: { id: deploymentCampaignId },
      onCompleted(data, errors) {
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
            id="components.DeploymentCampaign.resumeErrorFeedback"
            defaultMessage="Could not resume the campaign, please try again."
          />,
        );
      },
    });
  }, [deploymentCampaignId, resumeCampaign, setErrorFeedback]);

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
          id="pages.DeploymentCampaign.resumeButton"
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
          id="pages.DeploymentCampaign.pauseButton"
          defaultMessage="Pause"
        />
      </Button>
    );
  }

  return null;
};

type DeploymentCampaignContentProps = {
  deploymentCampaignId: string;
  getCampaignQuery: PreloadedQuery<DeploymentCampaign_getCampaign_Query>;
};

const DeploymentCampaignContent = ({
  deploymentCampaignId,
  getCampaignQuery,
}: DeploymentCampaignContentProps) => {
  const [errorFeedback, setErrorFeedback] = useState<React.ReactNode>(null);

  const { campaign } = usePreloadedQuery(GET_CAMPAIGN_QUERY, getCampaignQuery);

  useSubscription({
    subscription: CAMPAIGN_UPDATE_SUBSCRIPTION,
    variables: { id: deploymentCampaignId },
    updater: (store) => {
      const root = store.getRoot();
      const campaignRoot = root.getLinkedRecord("campaign", {
        id: deploymentCampaignId,
      });
      if (!campaignRoot) return;

      const campaignTargets = campaignRoot.getLinkedRecord("campaignTargets");
      const allEdges = campaignTargets?.getLinkedRecords("edges") ?? [];

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
          "DeploymentTargetsTabs_campaignTargets",
          filters,
        );
        if (!connection) continue;

        const nodes = allEdges
          .map((e) => e?.getLinkedRecord("node"))
          .filter(
            (n): n is NonNullable<typeof n> =>
              Boolean(n) && n?.getValue("status") === status,
          );

        const newEdges = nodes.map((node) =>
          ConnectionHandler.createEdge(
            store,
            connection,
            node,
            "CampaignTargetEdge",
          ),
        );

        connection.setLinkedRecords(newEdges, "edges");
      }
    },
  });

  if (!campaign) {
    return (
      <Result.NotFound
        title={
          <FormattedMessage
            id="pages.DeploymentCampaign.deploymentCampaignNotFound.title"
            defaultMessage="Deployment Campaign not found."
          />
        }
      >
        <Link route={Route.deploymentCampaigns}>
          <FormattedMessage
            id="pages.DeploymentCampaign.deploymentCampaignNotFound.message"
            defaultMessage="Return to the Deployment Campaign list."
          />
        </Link>
      </Result.NotFound>
    );
  }

  return (
    <Page>
      <Page.Header title={campaign.name}>
        <CampaignActions
          deploymentCampaignId={deploymentCampaignId}
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
        <Row>
          <Col lg={9}>
            <DeploymentCampaignForm campaignRef={campaign} />
          </Col>
          <Col lg={3}>
            <CampaignStatsChart campaignRef={campaign} />
          </Col>
        </Row>
        <hr className="bg-secondary border-2 border-top border-secondary" />
        <DeploymentTargetsTabs campaignRef={campaign} />
      </Page.Main>
    </Page>
  );
};

const DeploymentCampaignPage = () => {
  const { deploymentCampaignId = "" } = useParams();

  const [getCampaignQuery, getCampaign] =
    useQueryLoader<DeploymentCampaign_getCampaign_Query>(GET_CAMPAIGN_QUERY);

  const fetchCampaign = useCallback(() => {
    getCampaign(
      {
        deploymentCampaignId,
        first: RECORDS_TO_LOAD_FIRST,
      },
      { fetchPolicy: "network-only" },
    );
  }, [getCampaign, deploymentCampaignId]);

  useEffect(fetchCampaign, [fetchCampaign]);

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
          <DeploymentCampaignContent
            deploymentCampaignId={deploymentCampaignId}
            getCampaignQuery={getCampaignQuery}
          />
        )}
      </ErrorBoundary>
    </Suspense>
  );
};

export default DeploymentCampaignPage;
