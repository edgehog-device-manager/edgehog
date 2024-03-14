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
} from "react-relay/hooks";
import type { PreloadedQuery } from "react-relay/hooks";
import { FormattedMessage } from "react-intl";

import type {
  UpdateChannel_getUpdateChannel_Query,
  UpdateChannel_getUpdateChannel_Query$data,
} from "api/__generated__/UpdateChannel_getUpdateChannel_Query.graphql";
import type {
  UpdateChannel_getDeviceGroups_Query,
  UpdateChannel_getDeviceGroups_Query$data,
} from "api/__generated__/UpdateChannel_getDeviceGroups_Query.graphql";
import type { UpdateChannel_updateUpdateChannel_Mutation } from "api/__generated__/UpdateChannel_updateUpdateChannel_Mutation.graphql";
import type { UpdateChannel_deleteUpdateChannel_Mutation } from "api/__generated__/UpdateChannel_deleteUpdateChannel_Mutation.graphql";
import { Link, Route, useNavigate } from "Navigation";
import Alert from "components/Alert";
import Center from "components/Center";
import DeleteModal from "components/DeleteModal";
import Page from "components/Page";
import Result from "components/Result";
import Spinner from "components/Spinner";
import UpdateUpdateChannelForm from "forms/UpdateUpdateChannel";
import type { UpdateChannelData } from "forms/UpdateUpdateChannel";

const GET_UPDATE_CHANNEL_QUERY = graphql`
  query UpdateChannel_getUpdateChannel_Query($id: ID!) {
    updateChannel(id: $id) {
      id
      name
      handle
      ...UpdateUpdateChannel_UpdateChannelFragment
    }
  }
`;

const GET_DEVICE_GROUPS_QUERY = graphql`
  query UpdateChannel_getDeviceGroups_Query {
    deviceGroups {
      ...UpdateUpdateChannel_DeviceGroupsFragment
    }
  }
`;

const UPDATE_UPDATE_CHANNEL_MUTATION = graphql`
  mutation UpdateChannel_updateUpdateChannel_Mutation(
    $input: UpdateUpdateChannelInput!
  ) {
    updateUpdateChannel(input: $input) {
      updateChannel {
        id
        name
        handle
        targetGroups {
          id
          name
        }
      }
    }
  }
`;

const DELETE_UPDATE_CHANNEL_MUTATION = graphql`
  mutation UpdateChannel_deleteUpdateChannel_Mutation(
    $input: DeleteUpdateChannelInput!
  ) {
    deleteUpdateChannel(input: $input) {
      updateChannel {
        id
        targetGroups {
          id
        }
      }
    }
  }
`;

type UpdateChannelContentProps = {
  updateChannel: NonNullable<
    UpdateChannel_getUpdateChannel_Query$data["updateChannel"]
  >;
  deviceGroups: UpdateChannel_getDeviceGroups_Query$data["deviceGroups"];
  refreshDeviceGroups: () => void;
};

const UpdateChannelContent = ({
  updateChannel,
  deviceGroups,
  refreshDeviceGroups,
}: UpdateChannelContentProps) => {
  const updateChannelId = updateChannel.id;
  const navigate = useNavigate();
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
    const input = {
      updateChannelId,
    };
    deleteUpdateChannel({
      variables: { input },
      onCompleted(data, errors) {
        if (errors) {
          const errorFeedback = errors
            .map((error) => error.message)
            .join(". \n");
          setErrorFeedback(errorFeedback);
          return setShowDeleteModal(false);
        }
        navigate({ route: Route.updateChannels });
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
        if (!data.deleteUpdateChannel) {
          return;
        }
        const updateChannel = store
          .getRootField("deleteUpdateChannel")
          .getLinkedRecord("updateChannel");
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
      const input = {
        updateChannelId,
        ...updateChannel,
      };
      updateUpdateChannel({
        variables: { input },
        onCompleted(data, errors) {
          if (errors) {
            const errorFeedback = errors
              .map((error) => error.message)
              .join(". \n");
            return setErrorFeedback(errorFeedback);
          }
          setErrorFeedback(null);
          refreshDeviceGroups();
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
    [updateUpdateChannel, updateChannelId, refreshDeviceGroups],
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
            targetGroupsRef={deviceGroups}
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
  getDeviceGroupsQuery: PreloadedQuery<UpdateChannel_getDeviceGroups_Query>;
  refreshDeviceGroups: () => void;
};

const UpdateChannelWrapper = ({
  getUpdateChannelQuery,
  getDeviceGroupsQuery,
  refreshDeviceGroups,
}: UpdateChannelWrapperProps) => {
  const { updateChannel } = usePreloadedQuery(
    GET_UPDATE_CHANNEL_QUERY,
    getUpdateChannelQuery,
  );

  const { deviceGroups } = usePreloadedQuery(
    GET_DEVICE_GROUPS_QUERY,
    getDeviceGroupsQuery,
  );

  if (!updateChannel) {
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
      updateChannel={updateChannel}
      deviceGroups={deviceGroups}
      refreshDeviceGroups={refreshDeviceGroups}
    />
  );
};

const UpdateChannelPage = () => {
  const { updateChannelId = "" } = useParams();

  const [getUpdateChannelQuery, getUpdateChannel] =
    useQueryLoader<UpdateChannel_getUpdateChannel_Query>(
      GET_UPDATE_CHANNEL_QUERY,
    );

  const [getDeviceGroupsQuery, getDeviceGroups] =
    useQueryLoader<UpdateChannel_getDeviceGroups_Query>(
      GET_DEVICE_GROUPS_QUERY,
    );

  const refreshDeviceGroups = useCallback(
    () => getDeviceGroups({}, { fetchPolicy: "store-and-network" }),
    [getDeviceGroups],
  );

  useEffect(() => {
    getUpdateChannel({ id: updateChannelId }, { fetchPolicy: "network-only" });
    refreshDeviceGroups();
  }, [getUpdateChannel, updateChannelId, refreshDeviceGroups]);

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
        onReset={() => {
          getUpdateChannel(
            { id: updateChannelId },
            { fetchPolicy: "network-only" },
          );
          refreshDeviceGroups();
        }}
      >
        {getUpdateChannelQuery && getDeviceGroupsQuery && (
          <UpdateChannelWrapper
            getUpdateChannelQuery={getUpdateChannelQuery}
            getDeviceGroupsQuery={getDeviceGroupsQuery}
            refreshDeviceGroups={refreshDeviceGroups}
          />
        )}
      </ErrorBoundary>
    </Suspense>
  );
};

export default UpdateChannelPage;
