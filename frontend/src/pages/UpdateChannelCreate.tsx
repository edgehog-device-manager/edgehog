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

import type { UpdateChannelCreate_getDeviceGroups_Query } from "api/__generated__/UpdateChannelCreate_getDeviceGroups_Query.graphql";
import type { UpdateChannelCreate_createUpdateChannel_Mutation } from "api/__generated__/UpdateChannelCreate_createUpdateChannel_Mutation.graphql";
import Alert from "components/Alert";
import Center from "components/Center";
import CreateUpdateChannelForm from "forms/CreateUpdateChannel";
import type { UpdateChannelData } from "forms/CreateUpdateChannel";
import Page from "components/Page";
import Spinner from "components/Spinner";
import { Route, useNavigate } from "Navigation";

const GET_CREATE_UPDATE_CHANNEL_OPTIONS_QUERY = graphql`
  query UpdateChannelCreate_getDeviceGroups_Query {
    ...CreateUpdateChannel_OptionsFragment
  }
`;

const CREATE_UPDATE_CHANNEL_MUTATION = graphql`
  mutation UpdateChannelCreate_createUpdateChannel_Mutation(
    $input: CreateUpdateChannelInput!
  ) {
    createUpdateChannel(input: $input) {
      result {
        id
      }
    }
  }
`;

type UpdateChannelProps = {
  getCreateUpdateChannelOptionsQuery: PreloadedQuery<UpdateChannelCreate_getDeviceGroups_Query>;
};

const UpdateChannel = ({
  getCreateUpdateChannelOptionsQuery,
}: UpdateChannelProps) => {
  const [errorFeedback, setErrorFeedback] = useState<React.ReactNode>(null);
  const navigate = useNavigate();

  const updateChannelCreateData = usePreloadedQuery(
    GET_CREATE_UPDATE_CHANNEL_OPTIONS_QUERY,
    getCreateUpdateChannelOptionsQuery,
  );

  const [createUpdateChannel, isCreatingUpdateChannel] =
    useMutation<UpdateChannelCreate_createUpdateChannel_Mutation>(
      CREATE_UPDATE_CHANNEL_MUTATION,
    );

  const handleCreateUpdateChannel = useCallback(
    (updateChannel: UpdateChannelData) => {
      createUpdateChannel({
        variables: { input: updateChannel },
        onCompleted(data, errors) {
          const updateChannelId = data?.createUpdateChannel?.result?.id;
          if (updateChannelId) {
            return navigate({
              route: Route.updateChannelsEdit,
              params: { updateChannelId },
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
              id="pages.UpdateChannelCreate.creationErrorFeedback"
              defaultMessage="Could not create the Update Channel, please try again."
            />,
          );
        },
        updater(store, data) {
          if (!data?.createUpdateChannel?.result) {
            return;
          }

          const updateChannel = store
            .getRootField("createUpdateChannel")
            .getLinkedRecord("result");
          const root = store.getRoot();

          const updateChannels = root.getLinkedRecords("updateChannels");
          if (updateChannels) {
            root.setLinkedRecords(
              [...updateChannels, updateChannel],
              "updateChannels",
            );
          }
        },
      });
    },
    [createUpdateChannel, navigate],
  );

  return (
    <Page>
      <Page.Header
        title={
          <FormattedMessage
            id="pages.UpdateChannelCreate.title"
            defaultMessage="Create Update Channel"
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
        <CreateUpdateChannelForm
          queryRef={updateChannelCreateData}
          onSubmit={handleCreateUpdateChannel}
          isLoading={isCreatingUpdateChannel}
        />
      </Page.Main>
    </Page>
  );
};

const UpdateChannelCreatePage = () => {
  const [getCreateUpdateChannelOptionsQuery, getCreateUpdateChannelOptions] =
    useQueryLoader<UpdateChannelCreate_getDeviceGroups_Query>(
      GET_CREATE_UPDATE_CHANNEL_OPTIONS_QUERY,
    );

  const fetchCreateUpdateChannelOptions = useCallback(
    () => getCreateUpdateChannelOptions({}, { fetchPolicy: "network-only" }),
    [getCreateUpdateChannelOptions],
  );

  useEffect(fetchCreateUpdateChannelOptions, [fetchCreateUpdateChannelOptions]);

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
        onReset={fetchCreateUpdateChannelOptions}
      >
        {getCreateUpdateChannelOptionsQuery && (
          <UpdateChannel
            getCreateUpdateChannelOptionsQuery={
              getCreateUpdateChannelOptionsQuery
            }
          />
        )}
      </ErrorBoundary>
    </Suspense>
  );
};

export default UpdateChannelCreatePage;
