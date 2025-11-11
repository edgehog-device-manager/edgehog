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

import { Suspense, useCallback, useEffect } from "react";
import { ErrorBoundary } from "react-error-boundary";
import { FormattedMessage } from "react-intl";
import type { PreloadedQuery } from "react-relay/hooks";
import { graphql, usePreloadedQuery, useQueryLoader } from "react-relay/hooks";

import type { DeploymentCampaigns_getDeploymentCampaigns_Query } from "api/__generated__/DeploymentCampaigns_getDeploymentCampaigns_Query.graphql";

import Button from "components/Button";
import Center from "components/Center";
import Page from "components/Page";
import Spinner from "components/Spinner";
import DeploymentCampaignsTable from "components/DeploymentCampaignsTable";
import { Link, Route } from "Navigation";
import { RECORDS_TO_LOAD_FIRST } from "constants";

const GET_DEPLOYMENT_CAMPAIGNS_QUERY = graphql`
  query DeploymentCampaigns_getDeploymentCampaigns_Query(
    $first: Int
    $after: String
    $filter: DeploymentCampaignFilterInput = {}
  ) {
    ...DeploymentCampaignsTable_DeploymentCampaignFragment
      @arguments(filter: $filter)
  }
`;

interface DeploymentCampaignsContentProps {
  getDeploymentCampaignsQuery: PreloadedQuery<DeploymentCampaigns_getDeploymentCampaigns_Query>;
}

const DeploymentCampaignsContent = ({
  getDeploymentCampaignsQuery,
}: DeploymentCampaignsContentProps) => {
  const campaigns = usePreloadedQuery(
    GET_DEPLOYMENT_CAMPAIGNS_QUERY,
    getDeploymentCampaignsQuery,
  );

  return (
    <Page>
      <Page.Header
        title={
          <FormattedMessage
            id="pages.Campaigns.title"
            defaultMessage="Campaigns"
          />
        }
      >
        <Button as={Link} route={Route.deploymentCampaignsNew}>
          <FormattedMessage
            id="pages.DeploymentCampaigns.createButton"
            defaultMessage="Create Campaign"
          />
        </Button>
      </Page.Header>
      <Page.Main>
        <DeploymentCampaignsTable deploymentCampaignsData={campaigns} />
      </Page.Main>
    </Page>
  );
};

const DeploymentCampaignsPage = () => {
  const [getDeploymentCampaignsQuery, getDeploymentCampaigns] =
    useQueryLoader<DeploymentCampaigns_getDeploymentCampaigns_Query>(
      GET_DEPLOYMENT_CAMPAIGNS_QUERY,
    );

  const fetchDeploymentCampaigns = useCallback(
    () =>
      getDeploymentCampaigns(
        { first: RECORDS_TO_LOAD_FIRST },
        { fetchPolicy: "store-and-network" },
      ),
    [getDeploymentCampaigns],
  );

  useEffect(fetchDeploymentCampaigns, [fetchDeploymentCampaigns]);

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
        onReset={fetchDeploymentCampaigns}
      >
        {getDeploymentCampaignsQuery && (
          <DeploymentCampaignsContent
            getDeploymentCampaignsQuery={getDeploymentCampaignsQuery}
          />
        )}
      </ErrorBoundary>
    </Suspense>
  );
};

export default DeploymentCampaignsPage;
