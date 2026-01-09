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

import { Suspense, useCallback, useEffect, useRef, useState } from "react";
import { useParams } from "react-router-dom";
import { ErrorBoundary } from "react-error-boundary";
import { FormattedMessage } from "react-intl";
import {
  fetchQuery,
  graphql,
  useFragment,
  usePreloadedQuery,
  useRelayEnvironment,
  useQueryLoader,
} from "react-relay/hooks";
import type { PreloadedQuery } from "react-relay/hooks";
import type { Subscription } from "relay-runtime";

import type { DeploymentCampaign_getCampaign_Query } from "@/api/__generated__/DeploymentCampaign_getCampaign_Query.graphql";
import type { DeploymentCampaign_RefreshFragment$key } from "@/api/__generated__/DeploymentCampaign_RefreshFragment.graphql";

import Center from "@/components/Center";
import Col from "@/components/Col";
import Page from "@/components/Page";
import Result from "@/components/Result";
import Row from "@/components/Row";
import Spinner from "@/components/Spinner";
import CampaignStatsChart from "@/components/CampaignStatsChart";
import DeploymentCampaignForm from "@/forms/DeploymentCampaignForm";
import { Link, Route } from "@/Navigation";
import DeploymentTargetsTabs from "@/components/DeploymentTargetsTabs";
import { RECORDS_TO_LOAD_FIRST } from "@/constants";

const GET_CAMPAIGN_QUERY = graphql`
  query DeploymentCampaign_getCampaign_Query(
    $deploymentCampaignId: ID!
    $first: Int!
  ) {
    campaign(id: $deploymentCampaignId) {
      name
      ...DeploymentCampaignForm_CampaignFragment
      ...CampaignStatsChart_CampaignStatsChartFragment
      ...DeploymentCampaign_RefreshFragment
      ...DeploymentTargetsTabs_SuccessfulFragment @arguments(first: $first)
      ...DeploymentTargetsTabs_FailedFragment @arguments(first: $first)
      ...DeploymentTargetsTabs_InProgressFragment @arguments(first: $first)
      ...DeploymentTargetsTabs_IdleFragment @arguments(first: $first)
    }
  }
`;

const CAMPAIGN_REFRESH_FRAGMENT = graphql`
  fragment DeploymentCampaign_RefreshFragment on Campaign {
    id
    status
  }
`;

type DeploymentCampaignRefreshProps = {
  campaignRef: DeploymentCampaign_RefreshFragment$key;
};

const DeploymentCampaignRefresh = ({
  campaignRef,
}: DeploymentCampaignRefreshProps) => {
  const relayEnvironment = useRelayEnvironment();
  const { id, status } = useFragment(CAMPAIGN_REFRESH_FRAGMENT, campaignRef);
  const [isRefreshing, setIsRefreshing] = useState(false);

  // TODO: use GraphQL subscription (when available) to get deployments about Deployment Campaign
  const subscriptionRef = useRef<Subscription | null>(null);
  useEffect(() => {
    return () => {
      if (subscriptionRef.current) {
        subscriptionRef.current.unsubscribe();
      }
    };
  }, []);

  useEffect(() => {
    if (status === "FINISHED" || isRefreshing) {
      return;
    }
    const refreshTimerId = setTimeout(() => {
      setIsRefreshing(true);
      subscriptionRef.current = fetchQuery(
        relayEnvironment,
        GET_CAMPAIGN_QUERY,
        {
          deploymentCampaignId: id,
          first: RECORDS_TO_LOAD_FIRST,
        },
        { fetchPolicy: "network-only" },
      ).subscribe({
        complete: () => {
          setIsRefreshing(false);
        },
        error: () => {
          setIsRefreshing(false);
        },
      });
    }, 10000);

    return () => {
      clearTimeout(refreshTimerId);
    };
  }, [id, status, relayEnvironment, isRefreshing, setIsRefreshing]);

  return isRefreshing ? <Spinner className="ms-2 mx-auto" /> : null;
};

type DeploymentCampaignContentProps = {
  getCampaignQuery: PreloadedQuery<DeploymentCampaign_getCampaign_Query>;
};

const DeploymentCampaignContent = ({
  getCampaignQuery,
}: DeploymentCampaignContentProps) => {
  const { campaign } = usePreloadedQuery(GET_CAMPAIGN_QUERY, getCampaignQuery);

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
        <DeploymentCampaignRefresh campaignRef={campaign} />
      </Page.Header>
      <Page.Main>
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
          <DeploymentCampaignContent getCampaignQuery={getCampaignQuery} />
        )}
      </ErrorBoundary>
    </Suspense>
  );
};

export default DeploymentCampaignPage;
