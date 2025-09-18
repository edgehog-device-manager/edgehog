/*
  This file is part of Edgehog.

  Copyright 2023-2025 SECO Mind Srl

  Licensed under the Apache License, Version 2.0 (the "License");
  you may not use this file except in compliance with the License.
  You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

  Unless required by applicable law or agreed to in writing, software
  distributed under the License is distributed on an "AS IS" BASIS,
  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
  See the License for the specific language governing permissions and
  limitations under the License.

  SPDX-License-Identifier: Apache-2.0
*/

import { Suspense, useEffect, useCallback } from "react";
import { FormattedMessage } from "react-intl";
import { ErrorBoundary } from "react-error-boundary";
import { graphql, usePreloadedQuery, useQueryLoader } from "react-relay/hooks";
import type { PreloadedQuery } from "react-relay/hooks";

import type { Channels_getChannels_Query } from "api/__generated__/Channels_getChannels_Query.graphql";

import Button from "components/Button";
import Center from "components/Center";
import Page from "components/Page";
import Spinner from "components/Spinner";
import { Link, Route } from "Navigation";
import ChannelsTable from "components/ChannelsTable";

const CHANNELS_TO_LOAD_FIRST = 40;

const GET_CHANNELS_QUERY = graphql`
  query Channels_getChannels_Query(
    $first: Int
    $after: String
    $filter: ChannelFilterInput
  ) {
    ...ChannelsTable_ChannelFragment @arguments(filter: $filter)
  }
`;

type ChannelsContentProps = {
  getChannelsQuery: PreloadedQuery<Channels_getChannels_Query>;
};

const ChannelsContent = ({ getChannelsQuery }: ChannelsContentProps) => {
  const channels = usePreloadedQuery(GET_CHANNELS_QUERY, getChannelsQuery);

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
        <ChannelsTable channelsRef={channels} />
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
        { first: CHANNELS_TO_LOAD_FIRST },
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
