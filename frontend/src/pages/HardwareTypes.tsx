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

import type { HardwareTypes_getHardwareTypes_Query } from "@/api/__generated__/HardwareTypes_getHardwareTypes_Query.graphql";
import { HardwareTypes_HardwareTypesFragment$key } from "@/api/__generated__/HardwareTypes_HardwareTypesFragment.graphql";
import { HardwareTypes_PaginationQuery } from "@/api/__generated__/HardwareTypes_PaginationQuery.graphql";

import Button from "@/components/Button";
import Center from "@/components/Center";
import HardwareTypesTable from "@/components/HardwareTypesTable";
import Page from "@/components/Page";
import Result from "@/components/Result";
import SearchBox from "@/components/SearchBox";
import Spinner from "@/components/Spinner";
import { RECORDS_TO_LOAD_FIRST, RECORDS_TO_LOAD_NEXT } from "@/constants";
import { Link, Route } from "@/Navigation";

const GET_HARDWARE_TYPES_QUERY = graphql`
  query HardwareTypes_getHardwareTypes_Query(
    $first: Int
    $after: String
    $filter: HardwareTypeFilterInput = {}
  ) {
    hardwareTypes(first: $first, after: $after, filter: $filter) {
      count
    }
    ...HardwareTypes_HardwareTypesFragment
  }
`;

/* eslint-disable relay/unused-fields */
const HARDWARE_TYPES_FRAGMENT = graphql`
  fragment HardwareTypes_HardwareTypesFragment on RootQueryType
  @refetchable(queryName: "HardwareTypes_PaginationQuery") {
    hardwareTypes(first: $first, after: $after, filter: $filter)
      @connection(key: "HardwareTypes_hardwareTypes") {
      edges {
        node {
          __typename
        }
      }
      ...HardwareTypesTable_HardwareTypeEdgeFragment
    }
  }
`;

interface HardwareTypesLayoutContainerProps {
  hardwareTypesData: HardwareTypes_getHardwareTypes_Query["response"];
  searchText: string;
}
const HardwareTypesLayoutContainer = ({
  hardwareTypesData,
  searchText,
}: HardwareTypesLayoutContainerProps) => {
  const { data, loadNext, hasNext, isLoadingNext, refetch } =
    usePaginationFragment<
      HardwareTypes_PaginationQuery,
      HardwareTypes_HardwareTypesFragment$key
    >(HARDWARE_TYPES_FRAGMENT, hardwareTypesData);

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

  const loadNextHardwareTypes = useCallback(() => {
    if (hasNext && !isLoadingNext) {
      loadNext(RECORDS_TO_LOAD_NEXT);
    }
  }, [hasNext, isLoadingNext, loadNext]);

  const hardwareTypesRef = data?.hardwareTypes;

  if (!hardwareTypesRef) {
    return null;
  }

  return (
    <HardwareTypesTable
      hardwareTypesRef={hardwareTypesRef}
      loading={isLoadingNext}
      onLoadMore={hasNext ? loadNextHardwareTypes : undefined}
    />
  );
};

interface HardwareTypesContentProps {
  getHardwareTypesQuery: PreloadedQuery<HardwareTypes_getHardwareTypes_Query>;
}

const HardwareTypesContent = ({
  getHardwareTypesQuery,
}: HardwareTypesContentProps) => {
  const [searchText, setSearchText] = useState<string>("");

  const hardwareTypesData = usePreloadedQuery(
    GET_HARDWARE_TYPES_QUERY,
    getHardwareTypesQuery,
  );

  return (
    <Page>
      <Page.Header
        title={
          <FormattedMessage
            id="pages.HardwareTypes.title"
            defaultMessage="Hardware Types"
          />
        }
      >
        <Button as={Link} route={Route.hardwareTypesNew}>
          <FormattedMessage
            id="pages.HardwareTypes.createButton"
            defaultMessage="Create Hardware Type"
          />
        </Button>
      </Page.Header>
      <Page.Main>
        {hardwareTypesData.hardwareTypes?.count === 0 ? (
          <Result.EmptyList
            title={
              <FormattedMessage
                id="pages.HardwareTypes.noHardwareTypes.title"
                defaultMessage="This space is empty"
              />
            }
          >
            <FormattedMessage
              id="pages.HardwareTypes.noHardwareTypes.message"
              defaultMessage="You haven't created any hardware type yet."
            />
          </Result.EmptyList>
        ) : (
          <>
            <SearchBox
              className="flex-grow-1 pb-2"
              value={searchText}
              onChange={setSearchText}
            />
            <HardwareTypesLayoutContainer
              hardwareTypesData={hardwareTypesData}
              searchText={searchText}
            />
          </>
        )}
      </Page.Main>
    </Page>
  );
};

const HardwareTypesPage = () => {
  const [getHardwareTypesQuery, getHardwareTypes] =
    useQueryLoader<HardwareTypes_getHardwareTypes_Query>(
      GET_HARDWARE_TYPES_QUERY,
    );

  const fetchHardwareTypes = useCallback(
    () =>
      getHardwareTypes(
        { first: RECORDS_TO_LOAD_FIRST },
        { fetchPolicy: "store-and-network" },
      ),
    [getHardwareTypes],
  );

  useEffect(fetchHardwareTypes, [fetchHardwareTypes]);

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
        onReset={fetchHardwareTypes}
      >
        {getHardwareTypesQuery && (
          <HardwareTypesContent getHardwareTypesQuery={getHardwareTypesQuery} />
        )}
      </ErrorBoundary>
    </Suspense>
  );
};

export default HardwareTypesPage;
