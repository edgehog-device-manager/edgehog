// This file is part of Edgehog.
//
// Copyright 2021-2026 SECO Mind Srl
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

import type { SystemModels_getSystemModels_Query } from "@/api/__generated__/SystemModels_getSystemModels_Query.graphql";
import { SystemModels_PaginationQuery } from "@/api/__generated__/SystemModels_PaginationQuery.graphql";
import { SystemModels_SystemModelsFragment$key } from "@/api/__generated__/SystemModels_SystemModelsFragment.graphql";

import Button from "@/components/Button";
import Center from "@/components/Center";
import Page from "@/components/Page";
import Result from "@/components/Result";
import SearchBox from "@/components/SearchBox";
import Spinner from "@/components/Spinner";
import SystemModelsTable from "@/components/SystemModelsTable";
import { RECORDS_TO_LOAD_FIRST, RECORDS_TO_LOAD_NEXT } from "@/constants";
import { Link, Route } from "@/Navigation";

const GET_SYSTEM_MODELS_QUERY = graphql`
  query SystemModels_getSystemModels_Query(
    $first: Int
    $after: String
    $filter: SystemModelFilterInput
  ) {
    systemModels(first: $first, after: $after, filter: $filter) {
      count
    }
    ...SystemModels_SystemModelsFragment
  }
`;

/* eslint-disable relay/unused-fields */
const SYSTEM_MODELS_FRAGMENT = graphql`
  fragment SystemModels_SystemModelsFragment on RootQueryType
  @refetchable(queryName: "SystemModels_PaginationQuery") {
    systemModels(first: $first, after: $after, filter: $filter)
      @connection(key: "SystemModels_systemModels") {
      edges {
        node {
          __typename
        }
      }
      ...SystemModelsTable_SystemModelEdgeFragment
    }
  }
`;

interface SystemModelsLayoutContainerProps {
  systemModelsData: SystemModels_getSystemModels_Query["response"];
  searchText: string | null;
}
const SystemModelsLayoutContainer = ({
  systemModelsData,
  searchText,
}: SystemModelsLayoutContainerProps) => {
  const { data, loadNext, hasNext, isLoadingNext, refetch } =
    usePaginationFragment<
      SystemModels_PaginationQuery,
      SystemModels_SystemModelsFragment$key
    >(SYSTEM_MODELS_FRAGMENT, systemModelsData);

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
                    partNumbers: {
                      partNumber: {
                        ilike: `%${text}%`,
                      },
                    },
                  },
                  {
                    hardwareType: {
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

  const loadNextSystemModels = useCallback(() => {
    if (hasNext && !isLoadingNext) {
      loadNext(RECORDS_TO_LOAD_NEXT);
    }
  }, [hasNext, isLoadingNext, loadNext]);

  const systemModelsRef = data?.systemModels;

  if (!systemModelsRef) {
    return null;
  }

  return (
    <SystemModelsTable
      systemModelsRef={systemModelsRef}
      loading={isLoadingNext}
      onLoadMore={hasNext ? loadNextSystemModels : undefined}
    />
  );
};

type SystemModelsContentProps = {
  getSystemModelsQuery: PreloadedQuery<SystemModels_getSystemModels_Query>;
};

const SystemModelsContent = ({
  getSystemModelsQuery,
}: SystemModelsContentProps) => {
  const [searchText, setSearchText] = useState<string | null>(null);
  const systemModelsData = usePreloadedQuery(
    GET_SYSTEM_MODELS_QUERY,
    getSystemModelsQuery,
  );

  return (
    <Page>
      <Page.Header
        title={
          <FormattedMessage
            id="pages.SystemModels.title"
            defaultMessage="System Models"
          />
        }
      >
        <Button as={Link} route={Route.systemModelsNew}>
          <FormattedMessage
            id="pages.SystemModels.createButton"
            defaultMessage="Create System Model"
          />
        </Button>
      </Page.Header>
      <Page.Main>
        {systemModelsData.systemModels?.count === 0 ? (
          <Result.EmptyList
            title={
              <FormattedMessage
                id="pages.SystemModels.noSystemModels.title"
                defaultMessage="This space is empty"
              />
            }
          >
            <FormattedMessage
              id="pages.SystemModels.noSystemModels.message"
              defaultMessage="You haven't created any system model yet."
            />
          </Result.EmptyList>
        ) : (
          <>
            <SearchBox
              className="flex-grow-1 pb-2"
              value={searchText || ""}
              onChange={setSearchText}
            />
            <SystemModelsLayoutContainer
              systemModelsData={systemModelsData}
              searchText={searchText}
            />
          </>
        )}
      </Page.Main>
    </Page>
  );
};

const SystemModelsPage = () => {
  const [getSystemModelsQuery, getSystemModels] =
    useQueryLoader<SystemModels_getSystemModels_Query>(GET_SYSTEM_MODELS_QUERY);

  const fetchSystemModels = useCallback(
    () =>
      getSystemModels(
        { first: RECORDS_TO_LOAD_FIRST },
        { fetchPolicy: "store-and-network" },
      ),
    [getSystemModels],
  );

  useEffect(fetchSystemModels, [fetchSystemModels]);

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
        onReset={fetchSystemModels}
      >
        {getSystemModelsQuery && (
          <SystemModelsContent getSystemModelsQuery={getSystemModelsQuery} />
        )}
      </ErrorBoundary>
    </Suspense>
  );
};

export default SystemModelsPage;
