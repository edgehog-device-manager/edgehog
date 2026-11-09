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

import { Suspense, useCallback, useEffect, useState } from "react";
import { ErrorBoundary } from "react-error-boundary";
import { FormattedMessage } from "react-intl";
import {
  graphql,
  PreloadedQuery,
  usePaginationFragment,
  usePreloadedQuery,
  useQueryLoader,
} from "react-relay";
import { Card } from "react-bootstrap";

import type { AllowedRegistries_getAllowedRegistries_Query } from "@/api/__generated__/AllowedRegistries_getAllowedRegistries_Query.graphql";
import { AllowedRegistries_AllowedRegistriesFragment$key } from "@/api/__generated__/AllowedRegistries_AllowedRegistriesFragment.graphql";
import { AllowedRegistries_PaginationQuery } from "@/api/__generated__/AllowedRegistries_PaginationQuery.graphql";

import Button from "@/components/ui/button/Button";
import Center from "@/components/ui/center/Center";
import AllowedRegistriesTable from "@/components/apps/containers/allowed-registries-table/AllowedRegistriesTable";
import Page from "@/components/ui/page/Page";
import Spinner from "@/components/ui/spinner/Spinner";
import { RECORDS_TO_LOAD_FIRST } from "@/constants";
import useRelayConnectionPagination from "@/hooks/useRelayConnectionPagination";
import { Link, Route } from "@/Navigation";

const GET_ALLOWED_REGISTRIES_QUERY = graphql`
  query AllowedRegistries_getAllowedRegistries_Query(
    $first: Int
    $after: String
    $filter: AllowedRegistryFilterInput = {}
  ) {
    ...AllowedRegistries_AllowedRegistriesFragment
  }
`;

/* eslint-disable relay/unused-fields */
const ALLOWED_REGISTRIES_FRAGMENT = graphql`
  fragment AllowedRegistries_AllowedRegistriesFragment on RootQueryType
  @refetchable(queryName: "AllowedRegistries_PaginationQuery") {
    allowedRegistries(first: $first, after: $after, filter: $filter)
      @connection(key: "AllowedRegistries_allowedRegistries") {
      edges {
        node {
          __typename
        }
      }
      ...AllowedRegistriesTable_AllowedRegistryEdgeFragment
    }
  }
`;

interface AllowedRegistriesLayoutContainerProps {
  allowedRegistriesData: AllowedRegistries_getAllowedRegistries_Query["response"];
  searchText: string | null;
  onSearchChange: (text: string) => void;
}
const AllowedRegistriesLayoutContainer = ({
  allowedRegistriesData,
  searchText,
  onSearchChange,
}: AllowedRegistriesLayoutContainerProps) => {
  const { data, loadNext, hasNext, isLoadingNext, refetch } =
    usePaginationFragment<
      AllowedRegistries_PaginationQuery,
      AllowedRegistries_AllowedRegistriesFragment$key
    >(ALLOWED_REGISTRIES_FRAGMENT, allowedRegistriesData);

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
        registry: { ilike: `%${text}%` },
      };
    },
  });

  const allowedRegistriesRef = data?.allowedRegistries;

  if (!allowedRegistriesRef) {
    return null;
  }

  return (
    <AllowedRegistriesTable
      allowedRegistriesRef={allowedRegistriesRef}
      loading={isLoadingNext}
      onLoadMore={onLoadMore}
      searchText={searchText ?? ""}
      onSearchChange={onSearchChange}
    />
  );
};

interface AllowedRegistriesContentProps {
  getAllowedRegistriesQuery: PreloadedQuery<AllowedRegistries_getAllowedRegistries_Query>;
}

const AllowedRegistriesContent = ({
  getAllowedRegistriesQuery,
}: AllowedRegistriesContentProps) => {
  const [searchText, setSearchText] = useState<string | null>(null);
  const allowedRegistriesData =
    usePreloadedQuery<AllowedRegistries_getAllowedRegistries_Query>(
      GET_ALLOWED_REGISTRIES_QUERY,
      getAllowedRegistriesQuery,
    );

  return (
    <Page>
      <Page.Header
        title={
          <FormattedMessage
            id="pages.AllowedRegistries.title"
            defaultMessage="Allowed Registries"
          />
        }
      >
        <Button as={Link} route={Route.allowedRegistriesNew}>
          <FormattedMessage
            id="pages.AllowedRegistries.createButton"
            defaultMessage="Create Allowed Registry"
          />
        </Button>
      </Page.Header>
      <Page.Main>
        <Card className="gap-2 border-0 shadow-sm flex-grow-1 p-4 ">
          <AllowedRegistriesLayoutContainer
            allowedRegistriesData={allowedRegistriesData}
            searchText={searchText}
            onSearchChange={setSearchText}
          />
        </Card>
      </Page.Main>
    </Page>
  );
};

const AllowedRegistriesPage = () => {
  const [getAllowedRegistriesQuery, getAllowedRegistries] =
    useQueryLoader<AllowedRegistries_getAllowedRegistries_Query>(
      GET_ALLOWED_REGISTRIES_QUERY,
    );

  const fetchAllowedRegistries = useCallback(
    () =>
      getAllowedRegistries(
        { first: RECORDS_TO_LOAD_FIRST },
        { fetchPolicy: "store-and-network" },
      ),
    [getAllowedRegistries],
  );

  useEffect(fetchAllowedRegistries, [fetchAllowedRegistries]);

  return (
    <Suspense
      fallback={
        <Center data-testid="page-loading">
          <Spinner />
        </Center>
      }
    >
      <ErrorBoundary
        FallbackComponent={({ resetErrorBoundary }) => (
          <Center data-testid="page-error">
            <Page.LoadingError onRetry={resetErrorBoundary} />
          </Center>
        )}
        onReset={fetchAllowedRegistries}
      >
        {getAllowedRegistriesQuery && (
          <AllowedRegistriesContent
            getAllowedRegistriesQuery={getAllowedRegistriesQuery}
          />
        )}
      </ErrorBoundary>
    </Suspense>
  );
};

export default AllowedRegistriesPage;
