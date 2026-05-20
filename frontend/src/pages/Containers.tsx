// This file is part of Edgehog.
//
// Copyright 2026 SECO Mind Srl
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

import { Suspense, useCallback, useEffect, useState } from "react";
import { ErrorBoundary } from "react-error-boundary";
import { FormattedMessage } from "react-intl";
import type { PreloadedQuery } from "react-relay/hooks";
import {
  graphql,
  usePaginationFragment,
  usePreloadedQuery,
  useQueryLoader,
} from "react-relay/hooks";

import { Containers_ContainersFragment$key } from "@/api/__generated__/Containers_ContainersFragment.graphql";
import type { Containers_getContainers_Query } from "@/api/__generated__/Containers_getContainers_Query.graphql";
import { Containers_PaginationQuery } from "@/api/__generated__/Containers_PaginationQuery.graphql";

import Button from "@/components/Button";
import Center from "@/components/Center";
import ContainersTable from "@/components/ContainersTable";
import Page from "@/components/Page";
import SearchBox from "@/components/SearchBox";
import Spinner from "@/components/Spinner";
import { RECORDS_TO_LOAD_FIRST } from "@/constants";
import useRelayConnectionPagination from "@/hooks/useRelayConnectionPagination";
import { Link, Route } from "@/Navigation";

const GET_CONTAINERS_QUERY = graphql`
  query Containers_getContainers_Query(
    $first: Int
    $after: String
    $filter: ContainerFilterInput = {}
  ) {
    ...Containers_ContainersFragment
  }
`;

/* eslint-disable relay/unused-fields */
const CONTAINERS_FRAGMENT = graphql`
  fragment Containers_ContainersFragment on RootQueryType
  @refetchable(queryName: "Containers_PaginationQuery") {
    containers(first: $first, after: $after, filter: $filter)
      @connection(key: "Containers_containers") {
      edges {
        node {
          __typename
        }
      }
      ...ContainersTable_ContainerEdgeFragment
    }
  }
`;

interface ContainersLayoutContainerProps {
  containersData: Containers_getContainers_Query["response"];
  searchText: string | null;
}
const ContainersLayoutContainer = ({
  containersData,
  searchText,
}: ContainersLayoutContainerProps) => {
  const { data, loadNext, hasNext, isLoadingNext, refetch } =
    usePaginationFragment<
      Containers_PaginationQuery,
      Containers_ContainersFragment$key
    >(CONTAINERS_FRAGMENT, containersData);

  const { onLoadMore } = useRelayConnectionPagination({
    hasNext,
    isLoadingNext,
    loadNext,
    refetch,
    searchText,
    buildFilter: (text) => {
      if (text === "") {
        return undefined;
      }

      return {
        or: [
          { name: { ilike: `%${text}%` } },
          { image: { reference: { ilike: `%${text}%` } } },
        ],
      };
    },
  });

  const containersRef = data?.containers;

  if (!containersRef) {
    return null;
  }

  return (
    <ContainersTable
      containersRef={containersRef}
      loading={isLoadingNext}
      onLoadMore={onLoadMore}
    />
  );
};

interface ContainersContentProps {
  getContainersQuery: PreloadedQuery<Containers_getContainers_Query>;
}

const ContainersContent = ({ getContainersQuery }: ContainersContentProps) => {
  const [searchText, setSearchText] = useState<string | null>(null);

  const containersData = usePreloadedQuery(
    GET_CONTAINERS_QUERY,
    getContainersQuery,
  );

  return (
    <Page>
      <Page.Header
        title={
          <FormattedMessage
            id="pages.Containers.title"
            defaultMessage="Containers"
          />
        }
      >
        <Button as={Link} route={Route.containersNew}>
          <FormattedMessage
            id="pages.Containers.createButton"
            defaultMessage="Create Container"
          />
        </Button>
      </Page.Header>
      <Page.Main>
        <SearchBox
          className="flex-grow-1 pb-2"
          value={searchText || ""}
          onChange={setSearchText}
        />
        <ContainersLayoutContainer
          containersData={containersData}
          searchText={searchText}
        />
      </Page.Main>
    </Page>
  );
};

const ContainersPage = () => {
  const [getContainersQuery, getContainers] =
    useQueryLoader<Containers_getContainers_Query>(GET_CONTAINERS_QUERY);

  const fetchContainers = useCallback(
    () =>
      getContainers(
        { first: RECORDS_TO_LOAD_FIRST },
        { fetchPolicy: "store-and-network" },
      ),
    [getContainers],
  );

  useEffect(fetchContainers, [fetchContainers]);

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
        onReset={fetchContainers}
      >
        {getContainersQuery && (
          <ContainersContent getContainersQuery={getContainersQuery} />
        )}
      </ErrorBoundary>
    </Suspense>
  );
};

export default ContainersPage;
