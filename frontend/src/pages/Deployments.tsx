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

import type { Deployments_getDeployments_Query } from "api/__generated__/Deployments_getDeployments_Query.graphql";

import Center from "components/Center";
import DeploymentsTable from "components/DeploymentsTable";
import Page from "components/Page";
import Spinner from "components/Spinner";

const DEPLOYMENTS_TO_LOAD_FIRST = 10_000;

const GET_DEPLOYMENTS_QUERY = graphql`
  query Deployments_getDeployments_Query($first: Int, $after: String) {
    ...DeploymentsTable_DeploymentFragment
  }
`;

interface DeploymentsContentProps {
  getDeploymentsQuery: PreloadedQuery<Deployments_getDeployments_Query>;
}

const DeploymentsContent = ({
  getDeploymentsQuery,
}: DeploymentsContentProps) => {
  const deployments = usePreloadedQuery(
    GET_DEPLOYMENTS_QUERY,
    getDeploymentsQuery,
  );

  return (
    <Page>
      <Page.Header
        title={
          <FormattedMessage
            id="pages.Deployments.title"
            defaultMessage="Deployments"
          />
        }
      ></Page.Header>
      <Page.Main>
        <DeploymentsTable deploymentsRef={deployments ?? []} />
      </Page.Main>
    </Page>
  );
};

const DeploymentsPage = () => {
  const [getDeploymentsQuery, getDeployments] =
    useQueryLoader<Deployments_getDeployments_Query>(GET_DEPLOYMENTS_QUERY);

  const fetchDeployments = useCallback(
    () =>
      getDeployments(
        { first: DEPLOYMENTS_TO_LOAD_FIRST },
        { fetchPolicy: "store-and-network" },
      ),
    [getDeployments],
  );

  useEffect(fetchDeployments, [fetchDeployments]);

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
        onReset={fetchDeployments}
      >
        {getDeploymentsQuery && (
          <DeploymentsContent getDeploymentsQuery={getDeploymentsQuery} />
        )}
      </ErrorBoundary>
    </Suspense>
  );
};

export default DeploymentsPage;
