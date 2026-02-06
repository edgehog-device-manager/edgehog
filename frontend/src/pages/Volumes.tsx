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

import type { Volumes_getVolumes_Query } from "@/api/__generated__/Volumes_getVolumes_Query.graphql";
import { Volumes_PaginationQuery } from "@/api/__generated__/Volumes_PaginationQuery.graphql";
import { Volumes_VolumesFragment$key } from "@/api/__generated__/Volumes_VolumesFragment.graphql";

import Button from "@/components/Button";
import Center from "@/components/Center";
import Page from "@/components/Page";
import SearchBox from "@/components/SearchBox";
import Spinner from "@/components/Spinner";
import VolumesTable from "@/components/VolumesTable";
import { RECORDS_TO_LOAD_FIRST, RECORDS_TO_LOAD_NEXT } from "@/constants";
import { Link, Route } from "@/Navigation";

const GET_VOLUMES_QUERY = graphql`
  query Volumes_getVolumes_Query(
    $first: Int
    $after: String
    $filter: VolumeFilterInput = {}
  ) {
    ...Volumes_VolumesFragment
  }
`;

/* eslint-disable relay/unused-fields */
const VOLUMES_FRAGMENT = graphql`
  fragment Volumes_VolumesFragment on RootQueryType
  @refetchable(queryName: "Volumes_PaginationQuery") {
    volumes(first: $first, after: $after, filter: $filter)
      @connection(key: "Volumes_volumes") {
      edges {
        node {
          __typename
        }
      }
      ...VolumesTable_VolumeEdgeFragment
    }
  }
`;

interface VolumesLayoutContainerProps {
  volumesData: Volumes_getVolumes_Query["response"];
  searchText: string | null;
}
const VolumesLayoutContainer = ({
  volumesData,
  searchText,
}: VolumesLayoutContainerProps) => {
  const { data, loadNext, hasNext, isLoadingNext, refetch } =
    usePaginationFragment<Volumes_PaginationQuery, Volumes_VolumesFragment$key>(
      VOLUMES_FRAGMENT,
      volumesData,
    );

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

  const loadNextVolumes = useCallback(() => {
    if (hasNext && !isLoadingNext) {
      loadNext(RECORDS_TO_LOAD_NEXT);
    }
  }, [hasNext, isLoadingNext, loadNext]);

  const volumesRef = data?.volumes;

  if (!volumesRef) {
    return null;
  }

  return (
    <VolumesTable
      volumesRef={volumesRef}
      loading={isLoadingNext}
      onLoadMore={hasNext ? loadNextVolumes : undefined}
    />
  );
};

interface VolumesContentProps {
  getVolumesQuery: PreloadedQuery<Volumes_getVolumes_Query>;
}

const VolumesContent = ({ getVolumesQuery }: VolumesContentProps) => {
  const [searchText, setSearchText] = useState<string | null>(null);
  const volumesData = usePreloadedQuery(GET_VOLUMES_QUERY, getVolumesQuery);

  return (
    <Page>
      <Page.Header
        title={
          <FormattedMessage id="pages.Volumes.title" defaultMessage="Volumes" />
        }
      >
        <Button as={Link} route={Route.volumesNew}>
          <FormattedMessage
            id="pages.Volumes.createButton"
            defaultMessage="Create Volume"
          />
        </Button>
      </Page.Header>
      <Page.Main>
        <SearchBox
          className="flex-grow-1 pb-2"
          value={searchText || ""}
          onChange={setSearchText}
        />
        <VolumesLayoutContainer
          volumesData={volumesData}
          searchText={searchText}
        />
      </Page.Main>
    </Page>
  );
};

const VolumesPage = () => {
  const [getVolumesQuery, getVolumes] =
    useQueryLoader<Volumes_getVolumes_Query>(GET_VOLUMES_QUERY);

  const fetchVolumes = useCallback(
    () =>
      getVolumes(
        { first: RECORDS_TO_LOAD_FIRST },
        { fetchPolicy: "store-and-network" },
      ),
    [getVolumes],
  );

  useEffect(fetchVolumes, [fetchVolumes]);

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
        onReset={fetchVolumes}
      >
        {getVolumesQuery && (
          <VolumesContent getVolumesQuery={getVolumesQuery} />
        )}
      </ErrorBoundary>
    </Suspense>
  );
};

export default VolumesPage;
