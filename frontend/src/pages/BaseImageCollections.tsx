// This file is part of Edgehog.
//
// Copyright 2023-2026 SECO Mind Srl
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

import { BaseImageCollections_BaseImageCollectionsFragment$key } from "@/api/__generated__/BaseImageCollections_BaseImageCollectionsFragment.graphql";
import type { BaseImageCollections_getBaseImageCollections_Query } from "@/api/__generated__/BaseImageCollections_getBaseImageCollections_Query.graphql";
import { BaseImageCollections_PaginationQuery } from "@/api/__generated__/BaseImageCollections_PaginationQuery.graphql";

import BaseImageCollectionsTable from "@/components/BaseImageCollectionsTable";
import Button from "@/components/Button";
import Center from "@/components/Center";
import Page from "@/components/Page";
import SearchBox from "@/components/SearchBox";
import Spinner from "@/components/Spinner";
import { RECORDS_TO_LOAD_FIRST, RECORDS_TO_LOAD_NEXT } from "@/constants";
import { Link, Route } from "@/Navigation";

const GET_BASE_IMAGE_COLLECTIONS_QUERY = graphql`
  query BaseImageCollections_getBaseImageCollections_Query(
    $first: Int
    $after: String
    $filter: BaseImageCollectionFilterInput = {}
  ) {
    ...BaseImageCollections_BaseImageCollectionsFragment
  }
`;

/* eslint-disable relay/unused-fields */
const BASE_IMAGE_COLLECTIONS_FRAGMENT = graphql`
  fragment BaseImageCollections_BaseImageCollectionsFragment on RootQueryType
  @refetchable(queryName: "BaseImageCollections_PaginationQuery") {
    baseImageCollections(first: $first, after: $after, filter: $filter)
      @connection(key: "BaseImageCollections_baseImageCollections") {
      edges {
        node {
          __typename
        }
      }
      ...BaseImageCollectionsTable_BaseImageCollectionEdgeFragment
    }
  }
`;

interface BaseImageCollectionsLayoutContainerProps {
  baseImageCollectionsData: BaseImageCollections_getBaseImageCollections_Query["response"];
  searchText: string | null;
}
const BaseImageCollectionsLayoutContainer = ({
  baseImageCollectionsData,
  searchText,
}: BaseImageCollectionsLayoutContainerProps) => {
  const { data, loadNext, hasNext, isLoadingNext, refetch } =
    usePaginationFragment<
      BaseImageCollections_PaginationQuery,
      BaseImageCollections_BaseImageCollectionsFragment$key
    >(BASE_IMAGE_COLLECTIONS_FRAGMENT, baseImageCollectionsData);

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
                  { name: { ilike: `%${text}%` } },
                  { handle: { ilike: `%${text}%` } },
                  {
                    systemModel: {
                      name: {
                        ilike: `%${text}%`,
                      },
                    },
                  },
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

  const loadNextBaseImageCollections = useCallback(() => {
    if (hasNext && !isLoadingNext) {
      loadNext(RECORDS_TO_LOAD_NEXT);
    }
  }, [hasNext, isLoadingNext, loadNext]);

  const BaseImageCollectionsRef = data?.baseImageCollections || null;

  if (!BaseImageCollectionsRef) {
    return null;
  }

  return (
    <BaseImageCollectionsTable
      baseImageCollectionsRef={BaseImageCollectionsRef}
      loading={isLoadingNext}
      onLoadMore={hasNext ? loadNextBaseImageCollections : undefined}
    />
  );
};

interface BaseImageCollectionsContentProps {
  getBaseImageCollectionsQuery: PreloadedQuery<BaseImageCollections_getBaseImageCollections_Query>;
}

const BaseImageCollectionsContent = ({
  getBaseImageCollectionsQuery,
}: BaseImageCollectionsContentProps) => {
  const [searchText, setSearchText] = useState<string | null>(null);
  const baseImageCollectionsData = usePreloadedQuery(
    GET_BASE_IMAGE_COLLECTIONS_QUERY,
    getBaseImageCollectionsQuery,
  );

  return (
    <Page>
      <Page.Header
        title={
          <FormattedMessage
            id="pages.BaseImageCollections.title"
            defaultMessage="Base Image Collections"
          />
        }
      >
        <Button as={Link} route={Route.baseImageCollectionsNew}>
          <FormattedMessage
            id="pages.BaseImageCollections.createButton"
            defaultMessage="Create Base Image Collection"
          />
        </Button>
      </Page.Header>
      <Page.Main>
        <SearchBox
          className="flex-grow-1 pb-2"
          value={searchText || ""}
          onChange={setSearchText}
        />
        <BaseImageCollectionsLayoutContainer
          baseImageCollectionsData={baseImageCollectionsData}
          searchText={searchText}
        />
      </Page.Main>
    </Page>
  );
};

const BaseImageCollectionsPage = () => {
  const [getBaseImageCollectionsQuery, getBaseImageCollections] =
    useQueryLoader<BaseImageCollections_getBaseImageCollections_Query>(
      GET_BASE_IMAGE_COLLECTIONS_QUERY,
    );

  const fetchBaseImageCollections = useCallback(
    () =>
      getBaseImageCollections(
        { first: RECORDS_TO_LOAD_FIRST },
        { fetchPolicy: "store-and-network" },
      ),
    [getBaseImageCollections],
  );

  useEffect(fetchBaseImageCollections, [fetchBaseImageCollections]);

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
        onReset={fetchBaseImageCollections}
      >
        {getBaseImageCollectionsQuery && (
          <BaseImageCollectionsContent
            getBaseImageCollectionsQuery={getBaseImageCollectionsQuery}
          />
        )}
      </ErrorBoundary>
    </Suspense>
  );
};

export default BaseImageCollectionsPage;
