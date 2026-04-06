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

import type { Repositories_getRepositories_Query } from "@/api/__generated__/Repositories_getRepositories_Query.graphql";
import { Repositories_PaginationQuery } from "@/api/__generated__/Repositories_PaginationQuery.graphql";
import { Repositories_RepositoriesFragment$key } from "@/api/__generated__/Repositories_RepositoriesFragment.graphql";

import Button from "@/components/Button";
import Center from "@/components/Center";
import Page from "@/components/Page";
import RepositoriesTable from "@/components/RepositoriesTable";
import SearchBox from "@/components/SearchBox";
import Spinner from "@/components/Spinner";
import { RECORDS_TO_LOAD_FIRST } from "@/constants";
import useRelayConnectionPagination from "@/hooks/useRelayConnectionPagination";
import { Link, Route } from "@/Navigation";

const GET_REPOSITORIES_QUERY = graphql`
  query Repositories_getRepositories_Query(
    $first: Int
    $after: String
    $filter: RepositoryFilterInput = {}
  ) {
    ...Repositories_RepositoriesFragment
  }
`;

/* eslint-disable relay/unused-fields */
const REPOSITORIES_FRAGMENT = graphql`
  fragment Repositories_RepositoriesFragment on RootQueryType
  @refetchable(queryName: "Repositories_PaginationQuery") {
    repositories(first: $first, after: $after, filter: $filter)
      @connection(key: "Repositories_repositories") {
      edges {
        node {
          __typename
        }
      }
      ...RepositoriesTable_RepositoryEdgeFragment
    }
  }
`;

interface RepositoriesLayoutContainerProps {
  repositoriesData: Repositories_getRepositories_Query["response"];
  searchText: string | null;
}
const RepositoriesLayoutContainer = ({
  repositoriesData,
  searchText,
}: RepositoriesLayoutContainerProps) => {
  const { data, loadNext, hasNext, isLoadingNext, refetch } =
    usePaginationFragment<
      Repositories_PaginationQuery,
      Repositories_RepositoriesFragment$key
    >(REPOSITORIES_FRAGMENT, repositoriesData);

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
          { handle: { ilike: `%${text}%` } },
        ],
      };
    },
  });

  const repositoriesRef = data?.repositories || null;

  if (!repositoriesRef) {
    return null;
  }

  return (
    <RepositoriesTable
      repositoriesRef={repositoriesRef}
      loading={isLoadingNext}
      onLoadMore={onLoadMore}
    />
  );
};

interface RepositoriesContentProps {
  getRepositoriesQuery: PreloadedQuery<Repositories_getRepositories_Query>;
}

const RepositoriesContent = ({
  getRepositoriesQuery,
}: RepositoriesContentProps) => {
  const [searchText, setSearchText] = useState<string | null>(null);

  const repositoriesData = usePreloadedQuery(
    GET_REPOSITORIES_QUERY,
    getRepositoriesQuery,
  );

  return (
    <Page>
      <Page.Header
        title={
          <FormattedMessage
            id="pages.Repositories.title"
            defaultMessage="Repositories"
          />
        }
      >
        <Button as={Link} route={Route.repositoryNew}>
          <FormattedMessage
            id="pages.Repositories.createButton"
            defaultMessage="Create Repository"
          />
        </Button>
      </Page.Header>
      <Page.Main>
        <SearchBox
          className="flex-grow-1 pb-2"
          value={searchText || ""}
          onChange={setSearchText}
        />
        <RepositoriesLayoutContainer
          repositoriesData={repositoriesData}
          searchText={searchText}
        />
      </Page.Main>
    </Page>
  );
};

const RepositoriesPage = () => {
  const [getRepositoriesQuery, getRepositories] =
    useQueryLoader<Repositories_getRepositories_Query>(GET_REPOSITORIES_QUERY);

  const fetchRepositories = useCallback(
    () =>
      getRepositories(
        { first: RECORDS_TO_LOAD_FIRST },
        { fetchPolicy: "store-and-network" },
      ),
    [getRepositories],
  );

  useEffect(fetchRepositories, [fetchRepositories]);

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
        onReset={fetchRepositories}
      >
        {getRepositoriesQuery && (
          <RepositoriesContent getRepositoriesQuery={getRepositoriesQuery} />
        )}
      </ErrorBoundary>
    </Suspense>
  );
};

export default RepositoriesPage;
