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

import type { DeploymentCampaign_getDeploymentCampaign_Query } from "api/__generated__/DeploymentCampaign_getDeploymentCampaign_Query.graphql";
import type { DeploymentCampaign_RefreshFragment$key } from "api/__generated__/DeploymentCampaign_RefreshFragment.graphql";

import Center from "components/Center";
import Col from "components/Col";
import Page from "components/Page";
import Result from "components/Result";
import Row from "components/Row";
import Spinner from "components/Spinner";
import DeploymentCampaignStatsChart from "components/DeploymentCampaignStatsChart";
import DeploymentCampaignForm from "forms/DeploymentCampaignForm";
import { Link, Route } from "Navigation";

const GET_DEPLOYMENT_CAMPAIGN_QUERY = graphql`
  query DeploymentCampaign_getDeploymentCampaign_Query(
    $deploymentCampaignId: ID!
  ) {
    deploymentCampaign(id: $deploymentCampaignId) {
      name
      ...DeploymentCampaignForm_DeploymentCampaignFragment
      ...DeploymentCampaignStatsChart_DeploymentCampaignStatsChartFragment
      ...DeploymentCampaign_RefreshFragment
    }
  }
`;

const DEPLOYMENT_CAMPAIGN_REFRESH_FRAGMENT = graphql`
  fragment DeploymentCampaign_RefreshFragment on DeploymentCampaign {
    id
    status
  }
`;

type DeploymentCampaignRefreshProps = {
  deploymentCampaignRef: DeploymentCampaign_RefreshFragment$key;
};
const DeploymentCampaignRefresh = ({
  deploymentCampaignRef,
}: DeploymentCampaignRefreshProps) => {
  const relayEnvironment = useRelayEnvironment();
  const { id, status } = useFragment(
    DEPLOYMENT_CAMPAIGN_REFRESH_FRAGMENT,
    deploymentCampaignRef,
  );
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
        GET_DEPLOYMENT_CAMPAIGN_QUERY,
        { deploymentCampaignId: id },
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
  getDeploymentCampaignQuery: PreloadedQuery<DeploymentCampaign_getDeploymentCampaign_Query>;
};

const DeploymentCampaignContent = ({
  getDeploymentCampaignQuery,
}: DeploymentCampaignContentProps) => {
  const { deploymentCampaign } = usePreloadedQuery(
    GET_DEPLOYMENT_CAMPAIGN_QUERY,
    getDeploymentCampaignQuery,
  );

  if (!deploymentCampaign) {
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
      <Page.Header title={deploymentCampaign.name}>
        <DeploymentCampaignRefresh deploymentCampaignRef={deploymentCampaign} />
      </Page.Header>
      <Page.Main>
        <Row>
          <Col lg={9}>
            <DeploymentCampaignForm
              deploymentCampaignRef={deploymentCampaign}
            />
          </Col>
          <Col lg={3}>
            <DeploymentCampaignStatsChart
              deploymentCampaignRef={deploymentCampaign}
            />
          </Col>
        </Row>
      </Page.Main>
    </Page>
  );
};

const DeploymentCampaignPage = () => {
  const { deploymentCampaignId = "" } = useParams();

  const [getDeploymentCampaignQuery, getDeploymentCampaign] =
    useQueryLoader<DeploymentCampaign_getDeploymentCampaign_Query>(
      GET_DEPLOYMENT_CAMPAIGN_QUERY,
    );

  const fetchDeploymentCampaign = useCallback(() => {
    getDeploymentCampaign(
      { deploymentCampaignId },
      { fetchPolicy: "network-only" },
    );
  }, [getDeploymentCampaign, deploymentCampaignId]);

  useEffect(fetchDeploymentCampaign, [fetchDeploymentCampaign]);

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
        onReset={fetchDeploymentCampaign}
      >
        {getDeploymentCampaignQuery && (
          <DeploymentCampaignContent
            getDeploymentCampaignQuery={getDeploymentCampaignQuery}
          />
        )}
      </ErrorBoundary>
    </Suspense>
  );
};

export default DeploymentCampaignPage;
