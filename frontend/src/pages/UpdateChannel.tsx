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
import { useParams } from "react-router-dom";
import { ErrorBoundary } from "react-error-boundary";
import {
  graphql,
  useMutation,
  usePreloadedQuery,
  useQueryLoader,
  useRefetchableFragment,
} from "react-relay/hooks";
import type { PreloadedQuery } from "react-relay/hooks";
import { FormattedMessage } from "react-intl";

import { Link, Route, useNavigate } from "Navigation";
import Alert from "components/Alert";
import Center from "components/Center";
import DeleteModal from "components/DeleteModal";
import Page from "components/Page";
import Result from "components/Result";
import Spinner from "components/Spinner";
import UpdateUpdateChannelForm from "forms/UpdateUpdateChannel";
import type { UpdateChannelData } from "forms/UpdateUpdateChannel";

import type {
  UpdateChannel_getUpdateChannel_Query,
  UpdateChannel_getUpdateChannel_Query$data,
} from "api/__generated__/UpdateChannel_getUpdateChannel_Query.graphql";
import type { UpdateChannel_OptionsFragment$key } from "api/__generated__/UpdateChannel_OptionsFragment.graphql";
import type { UpdateChannel_refetchOptions_Query } from "api/__generated__/UpdateChannel_refetchOptions_Query.graphql";
import type { UpdateChannel_updateUpdateChannel_Mutation } from "api/__generated__/UpdateChannel_updateUpdateChannel_Mutation.graphql";
import type { UpdateChannel_deleteUpdateChannel_Mutation } from "api/__generated__/UpdateChannel_deleteUpdateChannel_Mutation.graphql";

const UPDATE_UPDATE_CHANNEL_OPTIONS_FRAGMENT = graphql`
  fragment UpdateChannel_OptionsFragment on RootQueryType
  @refetchable(queryName: "UpdateChannel_refetchOptions_Query") {
    ...UpdateUpdateChannel_OptionsFragment
  }
`;

const GET_UPDATE_CHANNEL_QUERY = graphql`
  query UpdateChannel_getUpdateChannel_Query($updateChannelId: ID!) {
    updateChannel(id: $updateChannelId) {
      id
      name
      handle
      ...UpdateUpdateChannel_UpdateChannelFragment
    }
    ...UpdateChannel_OptionsFragment
  }
`;

const UPDATE_UPDATE_CHANNEL_MUTATION = graphql`
  mutation UpdateChannel_updateUpdateChannel_Mutation(
    $updateChannelId: ID!
    $input: UpdateUpdateChannelInput!
  ) {
    updateUpdateChannel(id: $updateChannelId, input: $input) {
      result {
        id
        name
        handle
        ...UpdateUpdateChannel_UpdateChannelFragment
        targetGroups {
          id
          name
        }
      }
    }
  }
`;

const DELETE_UPDATE_CHANNEL_MUTATION = graphql`
  mutation UpdateChannel_deleteUpdateChannel_Mutation($updateChannelId: ID!) {
    deleteUpdateChannel(id: $updateChannelId) {
      result {
        id
        targetGroups {
          id
        }
      }
    }
  }
`;

type UpdateChannelContentProps = {
  queryRef: UpdateChannel_OptionsFragment$key;
  updateChannel: NonNullable<
    UpdateChannel_getUpdateChannel_Query$data["updateChannel"]
  >;
};

const UpdateChannelContent = ({
  queryRef,
  updateChannel,
}: UpdateChannelContentProps) => {
  const navigate = useNavigate();

  const updateChannelId = updateChannel.id;
  const [updateChannelOptions, refetchOptions] = useRefetchableFragment<
    UpdateChannel_refetchOptions_Query,
    UpdateChannel_OptionsFragment$key
  >(UPDATE_UPDATE_CHANNEL_OPTIONS_FRAGMENT, queryRef);

  const [showDeleteModal, setShowDeleteModal] = useState(false);
  const [errorFeedback, setErrorFeedback] = useState<React.ReactNode>(null);

  const handleShowDeleteModal = useCallback(() => {
    setShowDeleteModal(true);
  }, [setShowDeleteModal]);

  const [deleteUpdateChannel, isDeletingUpdateChannel] =
    useMutation<UpdateChannel_deleteUpdateChannel_Mutation>(
      DELETE_UPDATE_CHANNEL_MUTATION,
    );

  const handleDeleteUpdateChannel = useCallback(() => {
    deleteUpdateChannel({
      variables: { updateChannelId },
      onCompleted(data, errors) {
        if (!errors || errors.length === 0 || errors[0].code === "not_found") {
          return navigate({ route: Route.updateChannels });
        }

        const errorFeedback = errors
          .map(({ fields, message }) =>
            fields.length ? `${fields.join(" ")} ${message}` : message,
          )
          .join(". \n");
        setErrorFeedback(errorFeedback);
        setShowDeleteModal(false);
      },
      onError() {
        setErrorFeedback(
          <FormattedMessage
            id="pages.UpdateChannel.deletionErrorFeedback"
            defaultMessage="Could not delete the Update Channel, please try again."
          />,
        );
        setShowDeleteModal(false);
      },
      updater(store, data) {
        if (!data?.deleteUpdateChannel?.result?.id) {
          return;
        }
        const updateChannel = store
          .getRootField("deleteUpdateChannel")
          .getLinkedRecord("result");
        const updateChannelId = updateChannel.getDataID();
        const root = store.getRoot();

        const updateChannels = root.getLinkedRecords("updateChannels");
        if (updateChannels) {
          root.setLinkedRecords(
            updateChannels.filter(
              (updateChannel) => updateChannel.getDataID() !== updateChannelId,
            ),
            "updateChannels",
          );
        }

        const targetGroupIds = new Set(
          updateChannel
            .getLinkedRecords("targetGroups")
            .map((targetGroup) => targetGroup.getDataID()),
        );
        const deviceGroups = root.getLinkedRecords("deviceGroups");
        if (deviceGroups && targetGroupIds.size) {
          deviceGroups.forEach((deviceGroup) => {
            if (targetGroupIds.has(deviceGroup.getDataID())) {
              deviceGroup.invalidateRecord();
            }
          });
        }

        store.delete(updateChannelId);
      },
    });
  }, [deleteUpdateChannel, updateChannelId, navigate]);

  const [updateUpdateChannel, isUpdatingUpdateChannel] =
    useMutation<UpdateChannel_updateUpdateChannel_Mutation>(
      UPDATE_UPDATE_CHANNEL_MUTATION,
    );

  const handleUpdateUpdateChannel = useCallback(
    (updateChannel: UpdateChannelData) => {
      updateUpdateChannel({
        variables: { updateChannelId, input: updateChannel },
        onCompleted(data, errors) {
          if (data.updateUpdateChannel?.result) {
            setErrorFeedback(null);
            refetchOptions({}, { fetchPolicy: "store-and-network" });
            return;
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
              id="pages.UpdateChannel.updateErrorFeedback"
              defaultMessage="Could not update the Update Channel, please try again."
            />,
          );
        },
      });
    },
    [updateUpdateChannel, updateChannelId, refetchOptions],
  );

  return (
    <Page>
      <Page.Header title={updateChannel.name} />
      <Page.Main>
        <Alert
          show={!!errorFeedback}
          variant="danger"
          onClose={() => setErrorFeedback(null)}
          dismissible
        >
          {errorFeedback}
        </Alert>
        <div className="mb-3">
          <UpdateUpdateChannelForm
            updateChannelRef={updateChannel}
            optionsRef={updateChannelOptions}
            onSubmit={handleUpdateUpdateChannel}
            onDelete={handleShowDeleteModal}
            isLoading={isUpdatingUpdateChannel}
          />
        </div>
        {showDeleteModal && (
          <DeleteModal
            confirmText={updateChannel.handle}
            onCancel={() => setShowDeleteModal(false)}
            onConfirm={handleDeleteUpdateChannel}
            isDeleting={isDeletingUpdateChannel}
            title={
              <FormattedMessage
                id="pages.UpdateChannel.deleteModal.title"
                defaultMessage="Delete Update Channel"
                description="Title for the confirmation modal to delete a Update Channel"
              />
            }
          >
            <p>
              <FormattedMessage
                id="pages.UpdateChannel.deleteModal.description"
                defaultMessage="This action cannot be undone. This will permanently delete the Update Channel <bold>{updateChannel}</bold>."
                description="Description for the confirmation modal to delete a Update Channel"
                values={{
                  updateChannel: updateChannel.name,
                  bold: (chunks: React.ReactNode) => <strong>{chunks}</strong>,
                }}
              />
            </p>
          </DeleteModal>
        )}
      </Page.Main>
    </Page>
  );
};

type UpdateChannelWrapperProps = {
  getUpdateChannelQuery: PreloadedQuery<UpdateChannel_getUpdateChannel_Query>;
};

const UpdateChannelWrapper = ({
  getUpdateChannelQuery,
}: UpdateChannelWrapperProps) => {
  const queryData = usePreloadedQuery(
    GET_UPDATE_CHANNEL_QUERY,
    getUpdateChannelQuery,
  );

  if (!queryData.updateChannel) {
    return (
      <Result.NotFound
        title={
          <FormattedMessage
            id="pages.UpdateChannel.updateChannelNotFound.title"
            defaultMessage="Update Channel not found."
          />
        }
      >
        <Link route={Route.updateChannels}>
          <FormattedMessage
            id="pages.UpdateChannel.updateChannelNotFound.message"
            defaultMessage="Return to the Update Channel list."
          />
        </Link>
      </Result.NotFound>
    );
  }

  return (
    <UpdateChannelContent
      updateChannel={queryData.updateChannel}
      queryRef={queryData}
    />
  );
};

const UpdateChannelPage = () => {
  const { updateChannelId = "" } = useParams();

  const [getUpdateChannelQuery, getUpdateChannel] =
    useQueryLoader<UpdateChannel_getUpdateChannel_Query>(
      GET_UPDATE_CHANNEL_QUERY,
    );

  const fetchUpdateChannel = useCallback(
    () =>
      getUpdateChannel({ updateChannelId }, { fetchPolicy: "network-only" }),
    [getUpdateChannel, updateChannelId],
  );

  useEffect(fetchUpdateChannel, [fetchUpdateChannel]);

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
        onReset={fetchUpdateChannel}
      >
        {getUpdateChannelQuery && (
          <UpdateChannelWrapper getUpdateChannelQuery={getUpdateChannelQuery} />
        )}
      </ErrorBoundary>
    </Suspense>
  );
};

export default UpdateChannelPage;
