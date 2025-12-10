/*
 * This file is part of Edgehog.
 *
 * Copyright 2025 SECO Mind Srl
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

import { Suspense, useCallback, useEffect } from "react";
import { FormattedMessage } from "react-intl";
import { ErrorBoundary } from "react-error-boundary";
import { graphql, usePreloadedQuery, useQueryLoader } from "react-relay/hooks";
import type { PreloadedQuery } from "react-relay/hooks";

import type { Networks_getNetworks_Query } from "@/api/__generated__/Networks_getNetworks_Query.graphql";

import Page from "@/components/Page";
import Center from "@/components/Center";
import Spinner from "@/components/Spinner";
import NetworksTable from "@/components/NetworksTable";
import Button from "@/components/Button";
import { Link, Route } from "@/Navigation";
import { RECORDS_TO_LOAD_FIRST } from "@/constants";

const GET_NETWORKS_QUERY = graphql`
  query Networks_getNetworks_Query(
    $first: Int
    $after: String
    $filter: NetworkFilterInput = {}
  ) {
    ...NetworksTable_NetworkFragment @arguments(filter: $filter)
  }
`;

interface NetworksContentProps {
  getNetworksQuery: PreloadedQuery<Networks_getNetworks_Query>;
}

const NetworksContent = ({ getNetworksQuery }: NetworksContentProps) => {
  const networksRef = usePreloadedQuery(GET_NETWORKS_QUERY, getNetworksQuery);

  return (
    <Page>
      <Page.Header
        title={
          <FormattedMessage
            id="pages.Networks.title"
            defaultMessage="Networks"
          />
        }
      >
        <Button as={Link} route={Route.networksNew}>
          <FormattedMessage
            id="pages.Networks.createButton"
            defaultMessage="Create Network"
          />
        </Button>
      </Page.Header>
      <Page.Main>
        <NetworksTable networksRef={networksRef} />
      </Page.Main>
    </Page>
  );
};

const NetworksPage = () => {
  const [getNetworksQuery, getNetworks] =
    useQueryLoader<Networks_getNetworks_Query>(GET_NETWORKS_QUERY);

  const fetchNetworks = useCallback(
    () =>
      getNetworks(
        { first: RECORDS_TO_LOAD_FIRST },
        { fetchPolicy: "store-and-network" },
      ),
    [getNetworks],
  );

  useEffect(fetchNetworks, [fetchNetworks]);

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
        onReset={fetchNetworks}
      >
        {getNetworksQuery && (
          <NetworksContent getNetworksQuery={getNetworksQuery} />
        )}
      </ErrorBoundary>
    </Suspense>
  );
};

export default NetworksPage;
