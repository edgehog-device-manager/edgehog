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

import { Channels_ChannelsFragment$key } from "@/api/__generated__/Channels_ChannelsFragment.graphql";
import type { Channels_getChannels_Query } from "@/api/__generated__/Channels_getChannels_Query.graphql";
import { Channels_PaginationQuery } from "@/api/__generated__/Channels_PaginationQuery.graphql";

import Button from "@/components/Button";
import Center from "@/components/Center";
import ChannelsTable from "@/components/ChannelsTable";
import Page from "@/components/Page";
import SearchBox from "@/components/SearchBox";
import Spinner from "@/components/Spinner";
import { RECORDS_TO_LOAD_FIRST, RECORDS_TO_LOAD_NEXT } from "@/constants";
import { Link, Route } from "@/Navigation";

const GET_CHANNELS_QUERY = graphql`
  query Channels_getChannels_Query(
    $first: Int
    $after: String
    $filter: ChannelFilterInput = {}
  ) {
    ...Channels_ChannelsFragment
  }
`;

/* eslint-disable relay/unused-fields */
const CHANNELS_FRAGMENT = graphql`
  fragment Channels_ChannelsFragment on RootQueryType
  @refetchable(queryName: "Channels_PaginationQuery") {
    channels(first: $first, after: $after, filter: $filter)
      @connection(key: "Channels_channels") {
      edges {
        node {
          __typename
        }
      }
      ...ChannelsTable_ChannelEdgeFragment
    }
  }
`;

interface ChannelsLayoutContainerProps {
  channelsData: Channels_getChannels_Query["response"];
  searchText: string | null;
}
const ChannelsLayoutContainer = ({
  channelsData,
  searchText,
}: ChannelsLayoutContainerProps) => {
  const { data, loadNext, hasNext, isLoadingNext, refetch } =
    usePaginationFragment<
      Channels_PaginationQuery,
      Channels_ChannelsFragment$key
    >(CHANNELS_FRAGMENT, channelsData);

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
                    targetGroups: {
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

  const loadNextChannels = useCallback(() => {
    if (hasNext && !isLoadingNext) {
      loadNext(RECORDS_TO_LOAD_NEXT);
    }
  }, [hasNext, isLoadingNext, loadNext]);

  const channelsRef = data?.channels;

  if (!channelsRef) {
    return null;
  }

  return (
    <ChannelsTable
      channelsRef={channelsRef}
      loading={isLoadingNext}
      onLoadMore={hasNext ? loadNextChannels : undefined}
    />
  );
};

type ChannelsContentProps = {
  getChannelsQuery: PreloadedQuery<Channels_getChannels_Query>;
};

const ChannelsContent = ({ getChannelsQuery }: ChannelsContentProps) => {
  const [searchText, setSearchText] = useState<string | null>(null);
  const channelsData = usePreloadedQuery(GET_CHANNELS_QUERY, getChannelsQuery);

  return (
    <Page>
      <Page.Header
        title={
          <FormattedMessage
            id="pages.Channels.title"
            defaultMessage="Channels"
          />
        }
      >
        <Button as={Link} route={Route.channelsNew}>
          <FormattedMessage
            id="pages.Channels.createButton"
            defaultMessage="Create Channel"
          />
        </Button>
      </Page.Header>
      <Page.Main>
        <SearchBox
          className="flex-grow-1 pb-2"
          value={searchText || ""}
          onChange={setSearchText}
        />
        <ChannelsLayoutContainer
          channelsData={channelsData}
          searchText={searchText}
        />
      </Page.Main>
    </Page>
  );
};

const ChannelsPage = () => {
  const [getChannelsQuery, getChannels] =
    useQueryLoader<Channels_getChannels_Query>(GET_CHANNELS_QUERY);

  const fetchChannels = useCallback(
    () =>
      getChannels(
        { first: RECORDS_TO_LOAD_FIRST },
        { fetchPolicy: "store-and-network" },
      ),
    [getChannels],
  );

  useEffect(fetchChannels, [fetchChannels]);

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
        onReset={fetchChannels}
      >
        {getChannelsQuery && (
          <ChannelsContent getChannelsQuery={getChannelsQuery} />
        )}
      </ErrorBoundary>
    </Suspense>
  );
};

export default ChannelsPage;
