/*
 * This file is part of Edgehog.
 *
 * Copyright 2023-2025 SECO Mind Srl
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *    http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 *
 * SPDX-License-Identifier: Apache-2.0
 */

import { Suspense, useCallback, useEffect, useState } from "react";
import { useParams } from "react-router-dom";
import { ErrorBoundary } from "react-error-boundary";
import {
  ConnectionHandler,
  graphql,
  useMutation,
  usePreloadedQuery,
  useQueryLoader,
  useRefetchableFragment,
} from "react-relay/hooks";
import type { PreloadedQuery } from "react-relay/hooks";
import { FormattedMessage } from "react-intl";

import { Link, Route, useNavigate } from "@/Navigation";
import Alert from "@/components/Alert";
import Center from "@/components/Center";
import DeleteModal from "@/components/DeleteModal";
import Page from "@/components/Page";
import Result from "@/components/Result";
import Spinner from "@/components/Spinner";
import ChannelForm from "@/forms/UpdateChannel";
import type { ChannelOutputData } from "@/forms/UpdateChannel";

import type {
  Channel_getChannel_Query,
  Channel_getChannel_Query$data,
} from "@/api/__generated__/Channel_getChannel_Query.graphql";
import type { Channel_OptionsFragment$key } from "@/api/__generated__/Channel_OptionsFragment.graphql";
import type { Channel_refetchOptions_Query } from "@/api/__generated__/Channel_refetchOptions_Query.graphql";
import type { Channel_updateChannel_Mutation } from "@/api/__generated__/Channel_updateChannel_Mutation.graphql";
import type { Channel_deleteChannel_Mutation } from "@/api/__generated__/Channel_deleteChannel_Mutation.graphql";

const UPDATE_CHANNEL_OPTIONS_FRAGMENT = graphql`
  fragment Channel_OptionsFragment on RootQueryType
  @refetchable(queryName: "Channel_refetchOptions_Query") {
    ...UpdateChannel_OptionsFragment
  }
`;

const GET_CHANNEL_QUERY = graphql`
  query Channel_getChannel_Query($channelId: ID!) {
    channel(id: $channelId) {
      id
      name
      handle
      ...UpdateChannel_ChannelFragment
    }
    ...Channel_OptionsFragment
  }
`;

const UPDATE_CHANNEL_MUTATION = graphql`
  mutation Channel_updateChannel_Mutation(
    $channelId: ID!
    $input: UpdateChannelInput!
  ) {
    updateChannel(id: $channelId, input: $input) {
      result {
        id
        name
        handle
        ...UpdateChannel_ChannelFragment
        targetGroups {
          edges {
            node {
              id
              name
            }
          }
        }
      }
    }
  }
`;

const DELETE_CHANNEL_MUTATION = graphql`
  mutation Channel_deleteChannel_Mutation($channelId: ID!) {
    deleteChannel(id: $channelId) {
      result {
        id
        targetGroups {
          edges {
            node {
              id
            }
          }
        }
      }
    }
  }
`;

type ChannelContentProps = {
  queryRef: Channel_OptionsFragment$key;
  channel: NonNullable<Channel_getChannel_Query$data["channel"]>;
};

const ChannelContent = ({ queryRef, channel }: ChannelContentProps) => {
  const navigate = useNavigate();

  const channelId = channel.id;
  const [channelOptions, refetchOptions] = useRefetchableFragment<
    Channel_refetchOptions_Query,
    Channel_OptionsFragment$key
  >(UPDATE_CHANNEL_OPTIONS_FRAGMENT, queryRef);

  const [showDeleteModal, setShowDeleteModal] = useState(false);
  const [errorFeedback, setErrorFeedback] = useState<React.ReactNode>(null);

  const handleShowDeleteModal = useCallback(() => {
    setShowDeleteModal(true);
  }, [setShowDeleteModal]);

  const [deleteChannel, isDeletingChannel] =
    useMutation<Channel_deleteChannel_Mutation>(DELETE_CHANNEL_MUTATION);

  const handleDeleteChannel = useCallback(() => {
    deleteChannel({
      variables: { channelId },
      onCompleted(data, errors) {
        if (!errors || errors.length === 0 || errors[0].code === "not_found") {
          return navigate({ route: Route.channels });
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
            id="pages.Channel.deletionErrorFeedback"
            defaultMessage="Could not delete the Channel, please try again."
          />,
        );
        setShowDeleteModal(false);
      },
      updater(store, data) {
        const channelId = data?.deleteChannel?.result?.id;
        if (!channelId) {
          return;
        }
        const channel = store
          .getRootField("deleteChannel")
          .getLinkedRecord("result");

        const root = store.getRoot();

        const connection = ConnectionHandler.getConnection(
          root,
          "ChannelsTable_channels",
        );

        if (connection) {
          ConnectionHandler.deleteNode(connection, channelId);
        }

        const targetGroupIds = new Set(
          channel
            .getLinkedRecord("targetGroups")
            ?.getLinkedRecords("edges")
            ?.map((edge) => edge.getLinkedRecord("node").getDataID()) || [],
        );

        const deviceGroups = root.getLinkedRecord("deviceGroups");
        if (deviceGroups && targetGroupIds.size) {
          deviceGroups?.getLinkedRecords("edges")?.forEach((edge) => {
            const deviceGroup = edge.getLinkedRecord("node");
            if (deviceGroup && targetGroupIds.has(deviceGroup.getDataID())) {
              deviceGroup.invalidateRecord();
            }
          });
        }

        store.delete(channelId);
      },
    });
  }, [deleteChannel, channelId, navigate]);

  const [updateChannel, isUpdatingChannel] =
    useMutation<Channel_updateChannel_Mutation>(UPDATE_CHANNEL_MUTATION);

  const handleUpdateChannel = useCallback(
    (channel: ChannelOutputData) => {
      updateChannel({
        variables: { channelId, input: channel },
        onCompleted(data, errors) {
          if (data.updateChannel?.result) {
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
              id="pages.Channel.updateErrorFeedback"
              defaultMessage="Could not update the Channel, please try again."
            />,
          );
        },
      });
    },
    [updateChannel, channelId, refetchOptions],
  );

  return (
    <Page>
      <Page.Header title={channel.name} />
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
          <ChannelForm
            channelRef={channel}
            optionsRef={channelOptions}
            onSubmit={handleUpdateChannel}
            onDelete={handleShowDeleteModal}
            isLoading={isUpdatingChannel}
          />
        </div>
        {showDeleteModal && (
          <DeleteModal
            confirmText={channel.handle}
            onCancel={() => setShowDeleteModal(false)}
            onConfirm={handleDeleteChannel}
            isDeleting={isDeletingChannel}
            title={
              <FormattedMessage
                id="pages.Channel.deleteModal.title"
                defaultMessage="Delete Channel"
                description="Title for the confirmation modal to delete a Channel"
              />
            }
          >
            <p>
              <FormattedMessage
                id="pages.Channel.deleteModal.description"
                defaultMessage="This action cannot be undone. This will permanently delete the Channel <bold>{channel}</bold>."
                description="Description for the confirmation modal to delete a Channel"
                values={{
                  channel: channel.name,
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

type ChannelWrapperProps = {
  getChannelQuery: PreloadedQuery<Channel_getChannel_Query>;
};

const ChannelWrapper = ({ getChannelQuery }: ChannelWrapperProps) => {
  const queryData = usePreloadedQuery(GET_CHANNEL_QUERY, getChannelQuery);

  if (!queryData.channel) {
    return (
      <Result.NotFound
        title={
          <FormattedMessage
            id="pages.Channel.channelNotFound.title"
            defaultMessage="Channel not found."
          />
        }
      >
        <Link route={Route.channels}>
          <FormattedMessage
            id="pages.Channel.channelNotFound.message"
            defaultMessage="Return to the Channel list."
          />
        </Link>
      </Result.NotFound>
    );
  }

  return <ChannelContent channel={queryData.channel} queryRef={queryData} />;
};

const ChannelPage = () => {
  const { channelId = "" } = useParams();

  const [getChannelQuery, getChannel] =
    useQueryLoader<Channel_getChannel_Query>(GET_CHANNEL_QUERY);

  const fetchChannel = useCallback(
    () => getChannel({ channelId }, { fetchPolicy: "network-only" }),
    [getChannel, channelId],
  );

  useEffect(fetchChannel, [fetchChannel]);

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
        onReset={fetchChannel}
      >
        {getChannelQuery && (
          <ChannelWrapper getChannelQuery={getChannelQuery} />
        )}
      </ErrorBoundary>
    </Suspense>
  );
};

export default ChannelPage;
