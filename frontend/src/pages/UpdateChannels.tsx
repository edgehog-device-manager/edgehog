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

import type { UpdateChannels_getUpdateChannels_Query } from "api/__generated__/UpdateChannels_getUpdateChannels_Query.graphql";

import Button from "components/Button";
import Center from "components/Center";
import UpdateChannelsTable from "components/UpdateChannelsTable";
import Page from "components/Page";
import Spinner from "components/Spinner";
import { Link, Route } from "Navigation";

const UPDATE_CHANNELS_TO_LOAD_FIRST = 40;

const GET_UPDATE_CHANNELS_QUERY = graphql`
  query UpdateChannels_getUpdateChannels_Query(
    $first: Int
    $after: String
    $filter: UpdateChannelFilterInput
  ) {
    ...UpdateChannelsTable_UpdateChannelFragment @arguments(filter: $filter)
  }
`;

type UpdateChannelsContentProps = {
  getUpdateChannelsQuery: PreloadedQuery<UpdateChannels_getUpdateChannels_Query>;
};

const UpdateChannelsContent = ({
  getUpdateChannelsQuery,
}: UpdateChannelsContentProps) => {
  const updateChannels = usePreloadedQuery(
    GET_UPDATE_CHANNELS_QUERY,
    getUpdateChannelsQuery,
  );

  return (
    <Page>
      <Page.Header
        title={
          <FormattedMessage
            id="pages.UpdateChannels.title"
            defaultMessage="Update Channels"
          />
        }
      >
        <Button as={Link} route={Route.updateChannelsNew}>
          <FormattedMessage
            id="pages.UpdateChannels.createButton"
            defaultMessage="Create Update Channel"
          />
        </Button>
      </Page.Header>
      <Page.Main>
        <UpdateChannelsTable updateChannelsRef={updateChannels} />
      </Page.Main>
    </Page>
  );
};

const UpdateChannelsPage = () => {
  const [getUpdateChannelsQuery, getUpdateChannels] =
    useQueryLoader<UpdateChannels_getUpdateChannels_Query>(
      GET_UPDATE_CHANNELS_QUERY,
    );

  const fetchUpdateChannels = useCallback(
    () =>
      getUpdateChannels(
        { first: UPDATE_CHANNELS_TO_LOAD_FIRST },
        { fetchPolicy: "store-and-network" },
      ),
    [getUpdateChannels],
  );

  useEffect(fetchUpdateChannels, [fetchUpdateChannels]);

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
        onReset={fetchUpdateChannels}
      >
        {getUpdateChannelsQuery && (
          <UpdateChannelsContent
            getUpdateChannelsQuery={getUpdateChannelsQuery}
          />
        )}
      </ErrorBoundary>
    </Suspense>
  );
};

export default UpdateChannelsPage;
