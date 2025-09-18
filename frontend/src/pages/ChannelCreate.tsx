/*
  This file is part of Edgehog.

  Copyright 2023-2024 SECO Mind Srl

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

import { Suspense, useCallback, useEffect, useState } from "react";
import { FormattedMessage } from "react-intl";
import { ErrorBoundary } from "react-error-boundary";
import {
  graphql,
  useMutation,
  usePreloadedQuery,
  useQueryLoader,
} from "react-relay/hooks";
import type { PreloadedQuery } from "react-relay/hooks";

import type { ChannelCreate_getDeviceGroups_Query } from "api/__generated__/ChannelCreate_getDeviceGroups_Query.graphql";
import type { ChannelCreate_createChannel_Mutation } from "api/__generated__/ChannelCreate_createChannel_Mutation.graphql";
import Alert from "components/Alert";
import Center from "components/Center";
import CreateChannelForm from "forms/CreateChannel";
import type { ChannelData } from "forms/CreateChannel";
import Page from "components/Page";
import Spinner from "components/Spinner";
import { Route, useNavigate } from "Navigation";

const GET_CREATE_UPDATE_CHANNEL_OPTIONS_QUERY = graphql`
  query ChannelCreate_getDeviceGroups_Query {
    ...CreateChannel_OptionsFragment
  }
`;

const CREATE_UPDATE_CHANNEL_MUTATION = graphql`
  mutation ChannelCreate_createChannel_Mutation($input: CreateChannelInput!) {
    createChannel(input: $input) {
      result {
        id
      }
    }
  }
`;

type ChannelProps = {
  getCreateChannelOptionsQuery: PreloadedQuery<ChannelCreate_getDeviceGroups_Query>;
};

const Channel = ({ getCreateChannelOptionsQuery }: ChannelProps) => {
  const [errorFeedback, setErrorFeedback] = useState<React.ReactNode>(null);
  const navigate = useNavigate();

  const channelCreateData = usePreloadedQuery(
    GET_CREATE_UPDATE_CHANNEL_OPTIONS_QUERY,
    getCreateChannelOptionsQuery,
  );

  const [createChannel, isCreatingChannel] =
    useMutation<ChannelCreate_createChannel_Mutation>(
      CREATE_UPDATE_CHANNEL_MUTATION,
    );

  const handleCreateChannel = useCallback(
    (channel: ChannelData) => {
      createChannel({
        variables: { input: channel },
        onCompleted(data, errors) {
          const channelId = data?.createChannel?.result?.id;
          if (channelId) {
            return navigate({
              route: Route.channelsEdit,
              params: { channelId },
            });
          }
          if (errors) {
            const errorFeedback = errors
              .map(({ fields, message }) =>
                fields.length ? `${fields.join(" ")} ${message}` : message,
              )
              .join(". \n");
            return setErrorFeedback(errorFeedback);
          }
        },
        onError() {
          setErrorFeedback(
            <FormattedMessage
              id="pages.ChannelCreate.creationErrorFeedback"
              defaultMessage="Could not create the Channel, please try again."
            />,
          );
        },
        updater(store, data) {
          if (!data?.createChannel?.result) {
            return;
          }

          const channel = store
            .getRootField("createChannel")
            .getLinkedRecord("result");
          const root = store.getRoot();

          const channels = root.getLinkedRecords("channels");
          if (channels) {
            root.setLinkedRecords([...channels, channel], "channels");
          }
        },
      });
    },
    [createChannel, navigate],
  );

  return (
    <Page>
      <Page.Header
        title={
          <FormattedMessage
            id="pages.ChannelCreate.title"
            defaultMessage="Create Channel"
          />
        }
      />
      <Page.Main>
        <Alert
          show={!!errorFeedback}
          variant="danger"
          onClose={() => setErrorFeedback(null)}
          dismissible
        >
          {errorFeedback}
        </Alert>
        <CreateChannelForm
          queryRef={channelCreateData}
          onSubmit={handleCreateChannel}
          isLoading={isCreatingChannel}
        />
      </Page.Main>
    </Page>
  );
};

const ChannelCreatePage = () => {
  const [getCreateChannelOptionsQuery, getCreateChannelOptions] =
    useQueryLoader<ChannelCreate_getDeviceGroups_Query>(
      GET_CREATE_UPDATE_CHANNEL_OPTIONS_QUERY,
    );

  const fetchCreateChannelOptions = useCallback(
    () => getCreateChannelOptions({}, { fetchPolicy: "network-only" }),
    [getCreateChannelOptions],
  );

  useEffect(fetchCreateChannelOptions, [fetchCreateChannelOptions]);

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
        onReset={fetchCreateChannelOptions}
      >
        {getCreateChannelOptionsQuery && (
          <Channel
            getCreateChannelOptionsQuery={getCreateChannelOptionsQuery}
          />
        )}
      </ErrorBoundary>
    </Suspense>
  );
};

export default ChannelCreatePage;
