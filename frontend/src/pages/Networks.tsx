// This file is part of Edgehog.
//
// Copyright 2025, 2026 SECO Mind Srl
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//    http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//
// SPDX-License-Identifier: Apache-2.0

import _ from "lodash";
import { Suspense, useCallback, useEffect, useMemo, useState } from "react";
import { ErrorBoundary } from "react-error-boundary";
import { FormattedMessage } from "react-intl";
import type { PreloadedQuery } from "react-relay/hooks";
import {
  graphql,
  usePaginationFragment,
  usePreloadedQuery,
  useQueryLoader,
} from "react-relay/hooks";

import type { Networks_getNetworks_Query } from "@/api/__generated__/Networks_getNetworks_Query.graphql";
import { Networks_NetworksFragment$key } from "@/api/__generated__/Networks_NetworksFragment.graphql";
import { Networks_PaginationQuery } from "@/api/__generated__/Networks_PaginationQuery.graphql";

import Button from "@/components/Button";
import Center from "@/components/Center";
import NetworksTable from "@/components/NetworksTable";
import Page from "@/components/Page";
import SearchBox from "@/components/SearchBox";
import Spinner from "@/components/Spinner";
import { RECORDS_TO_LOAD_FIRST, RECORDS_TO_LOAD_NEXT } from "@/constants";
import { Link, Route } from "@/Navigation";

const GET_NETWORKS_QUERY = graphql`
  query Networks_getNetworks_Query(
    $first: Int
    $after: String
    $filter: NetworkFilterInput = {}
  ) {
    ...Networks_NetworksFragment
  }
`;

/* eslint-disable relay/unused-fields */
const NETWORKS_FRAGMENT = graphql`
  fragment Networks_NetworksFragment on RootQueryType
  @refetchable(queryName: "Networks_PaginationQuery") {
    networks(first: $first, after: $after, filter: $filter)
      @connection(key: "Networks_networks") {
      edges {
        node {
          __typename
        }
      }
      ...NetworksTable_NetworkEdgeFragment
    }
  }
`;

interface NetworksLayoutContainerProps {
  networksData: Networks_getNetworks_Query["response"];
  searchText: string | null;
}
const NetworksLayoutContainer = ({
  networksData,
  searchText,
}: NetworksLayoutContainerProps) => {
  const { data, loadNext, hasNext, isLoadingNext, refetch } =
    usePaginationFragment<
      Networks_PaginationQuery,
      Networks_NetworksFragment$key
    >(NETWORKS_FRAGMENT, networksData);
  const debounceRefetch = useMemo(
    () =>
      _.debounce((text: string) => {
        if (text === "") {
          refetch(
            {
              first: RECORDS_TO_LOAD_FIRST,
            },
            { fetchPolicy: "network-only" },
          );
        } else {
          refetch(
            {
              first: RECORDS_TO_LOAD_FIRST,
              filter: {
                or: [
                  { label: { ilike: `%${text}%` } },
                  { driver: { ilike: `%${text}%` } },
                ],
              },
            },
            { fetchPolicy: "network-only" },
          );
        }
      }, 500),
    [refetch],
  );

  useEffect(() => {
    if (searchText !== null) {
      debounceRefetch(searchText);
    }
  }, [debounceRefetch, searchText]);

  const loadNextNetworks = useCallback(() => {
    if (hasNext && !isLoadingNext) {
      loadNext(RECORDS_TO_LOAD_NEXT);
    }
  }, [hasNext, isLoadingNext, loadNext]);

  const networksRef = data?.networks;

  if (!networksRef) {
    return null;
  }

  return (
    <NetworksTable
      networksRef={networksRef}
      loading={isLoadingNext}
      onLoadMore={hasNext ? loadNextNetworks : undefined}
    />
  );
};

interface NetworksContentProps {
  getNetworksQuery: PreloadedQuery<Networks_getNetworks_Query>;
}

const NetworksContent = ({ getNetworksQuery }: NetworksContentProps) => {
  const [searchText, setSearchText] = useState<string | null>(null);
  const networksData = usePreloadedQuery(GET_NETWORKS_QUERY, getNetworksQuery);

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
        <SearchBox
          className="flex-grow-1 pb-2"
          value={searchText || ""}
          onChange={setSearchText}
        />
        <NetworksLayoutContainer
          networksData={networksData}
          searchText={searchText}
        />
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
