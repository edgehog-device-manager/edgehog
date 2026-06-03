/*
 * This file is part of Edgehog.
 *
 * Copyright 2026 SECO Mind Srl
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

import React, { useCallback, useMemo, useState } from "react";
import { FormattedMessage, useIntl } from "react-intl";
import {
  ConnectionHandler,
  graphql,
  useMutation,
  usePaginationFragment,
  useSubscription,
} from "react-relay/hooks";
import { useParams } from "react-router-dom";
import { PayloadError } from "relay-runtime";
import useRelayConnectionPagination from "@/hooks/useRelayConnectionPagination";

import type { FilesDeleteTab_PaginationQuery } from "@/api/__generated__/FilesDeleteTab_PaginationQuery.graphql";
import type { FilesDeleteTab_createFileDeleteRequest_Mutation } from "@/api/__generated__/FilesDeleteTab_createFileDeleteRequest_Mutation.graphql";
import type { FilesDeleteTab_fileDeleteRequest_Subscription } from "@/api/__generated__/FilesDeleteTab_fileDeleteRequest_Subscription.graphql";
import type { FilesDeleteTab_fileManagement$key } from "@/api/__generated__/FilesDeleteTab_fileManagement.graphql";
import type { FilesDeleteTab_storageFileDownloadRequests_PaginationQuery } from "@/api/__generated__/FilesDeleteTab_storageFileDownloadRequests_PaginationQuery.graphql";
import type { FilesDeleteTab_storageFileDownloadRequests$key } from "@/api/__generated__/FilesDeleteTab_storageFileDownloadRequests.graphql";

import Alert from "@/components/Alert";
import FileDeleteRequestsTable from "@/components/FileDeleteRequestsTable";
import Stack from "@/components/Stack";
import { Tab } from "@/components/Tabs";
import ManualFileDeleteRequestForm, {
  type ManualFileDeleteRequestFormValues,
  type StorageSourceOption,
} from "@/forms/ManualFileDeleteRequestForm";

// We use graphql fields below in table columns configuration
/* eslint-disable relay/unused-fields */
const DEVICE_FILES_FRAGMENT = graphql`
  fragment FilesDeleteTab_fileManagement on Device
  @refetchable(queryName: "FilesDeleteTab_PaginationQuery") {
    capabilities
    fileDeleteRequests(first: $first, after: $after)
      @connection(key: "FilesDeleteTab_fileDeleteRequests") {
      edges {
        node {
          force
          status
          responseCode
          responseMessages
          fileDownloadRequest {
            fileName
          }
        }
      }
    }
  }
`;

const DEVICE_STORAGE_FILE_DOWNLOAD_REQUESTS_FRAGMENT = graphql`
  fragment FilesDeleteTab_storageFileDownloadRequests on Device
  @refetchable(
    queryName: "FilesDeleteTab_storageFileDownloadRequests_PaginationQuery"
  )
  @argumentDefinitions(first: { type: "Int" }, after: { type: "String" }) {
    storageFileDownloadRequests: fileDownloadRequests(
      first: $first
      after: $after
      filter: {
        destinationType: { eq: STORAGE }
        status: { eq: COMPLETED }
        deleted: { eq: false }
      }
    ) @connection(key: "FilesDeleteTab_storageFileDownloadRequests") {
      edges {
        node {
          id
          requestName
          fileName
        }
      }
    }
  }
`;

const DEVICE_CREATE_FILE_DELETE_REQUEST_MUTATION = graphql`
  mutation FilesDeleteTab_createFileDeleteRequest_Mutation(
    $input: CreateFileDeleteRequestInput!
  ) {
    createFileDeleteRequest(input: $input) {
      result {
        id
        force
        status
        responseCode
        responseMessages
        fileDownloadRequest {
          fileName
        }
      }
    }
  }
`;

const FILE_DELETE_REQUEST_UPDATED_SUBSCRIPTION = graphql`
  subscription FilesDeleteTab_fileDeleteRequest_Subscription($deviceId: ID!) {
    fileDeleteRequestsByDevice(deviceId: $deviceId) {
      updated {
        id
        force
        status
        responseCode
        responseMessages
        fileDownloadRequest {
          fileName
        }
      }
    }
  }
`;

const formatPayloadErrors = (errors: readonly PayloadError[]): string => {
  return errors
    .map(({ fields, message }) =>
      fields?.length ? `${fields.join(", ")}: ${message}` : message,
    )
    .join(". \n");
};

type ManualFileDeleteRequestFormWrapperProps = {
  setErrorFeedback: (feedback: React.ReactNode) => void;
  deviceId: string;
  deleteOptions: StorageSourceOption[];
  onLoadMoreDeleteOptions?: () => void;
  isOnline: boolean;
};

const ManualFileDeleteRequestFormWrapper = ({
  setErrorFeedback,
  deviceId,
  deleteOptions,
  onLoadMoreDeleteOptions,
  isOnline,
}: ManualFileDeleteRequestFormWrapperProps) => {
  const intl = useIntl();

  const [createFileDeleteRequest, isCreating] =
    useMutation<FilesDeleteTab_createFileDeleteRequest_Mutation>(
      DEVICE_CREATE_FILE_DELETE_REQUEST_MUTATION,
    );

  const handleSubmit = useCallback(
    async (values: ManualFileDeleteRequestFormValues) => {
      if (!isOnline) {
        setErrorFeedback(
          <FormattedMessage
            id="components.DeviceTabs.FilesDeleteTab.deviceOffline"
            defaultMessage="The device is offline."
          />,
        );
        return;
      }

      setErrorFeedback(null);

      try {
        await new Promise<void>((resolve, reject) => {
          createFileDeleteRequest({
            variables: {
              input: {
                deviceId,
                fileDownloadRequestId: values.fileDownloadRequestId,
                force: values.force,
              },
            },
            onCompleted(_responseData, errors) {
              if (errors && errors.length > 0) {
                reject(new Error(formatPayloadErrors(errors)));
                return;
              }
              resolve();
            },
            updater(store, data) {
              const newRequestId = data?.createFileDeleteRequest?.result?.id;
              if (!newRequestId) return;

              const newRequest = store.get(newRequestId);
              const storedDevice = store.get(deviceId);
              if (!storedDevice || !newRequest) return;

              const connection = ConnectionHandler.getConnection(
                storedDevice,
                "FilesDeleteTab_fileDeleteRequests",
              );
              if (!connection) return;

              const edges = connection.getLinkedRecords("edges") ?? [];
              const alreadyPresent = edges.some(
                (edge) =>
                  edge?.getLinkedRecord("node")?.getDataID() === newRequestId,
              );
              if (alreadyPresent) return;

              const edge = ConnectionHandler.createEdge(
                store,
                connection,
                newRequest,
                "FileDeleteRequestEdge",
              );
              ConnectionHandler.insertEdgeBefore(connection, edge);
            },
            onError(error) {
              reject(error);
            },
          });
        });
      } catch (error) {
        setErrorFeedback(
          error instanceof Error
            ? error.message
            : intl.formatMessage({
                id: "components.DeviceTabs.FilesDeleteTab.unknownError",
                defaultMessage: "Unknown error.",
              }),
        );
      }
    },
    [createFileDeleteRequest, deviceId, intl, isOnline, setErrorFeedback],
  );

  return (
    <ManualFileDeleteRequestForm
      isLoading={isCreating}
      onSubmit={handleSubmit}
      deleteOptions={deleteOptions}
      onLoadMoreDeleteOptions={onLoadMoreDeleteOptions}
    />
  );
};

type FilesDeleteTabProps = {
  deviceRef: FilesDeleteTab_fileManagement$key &
    FilesDeleteTab_storageFileDownloadRequests$key;
  embedded?: boolean;
  isOnline?: boolean;
};

const FilesDeleteTab = ({
  deviceRef,
  embedded = false,
  isOnline = false,
}: FilesDeleteTabProps) => {
  const intl = useIntl();
  const { deviceId = "" } = useParams();

  const [errorFeedback, setErrorFeedback] = useState<React.ReactNode>(null);

  const { data } = usePaginationFragment<
    FilesDeleteTab_PaginationQuery,
    FilesDeleteTab_fileManagement$key
  >(DEVICE_FILES_FRAGMENT, deviceRef);

  const {
    data: storageData,
    loadNext: loadNextStorage,
    hasNext: hasNextStorage,
    isLoadingNext: isLoadingStorageNext,
  } = usePaginationFragment<
    FilesDeleteTab_storageFileDownloadRequests_PaginationQuery,
    FilesDeleteTab_storageFileDownloadRequests$key
  >(DEVICE_STORAGE_FILE_DOWNLOAD_REQUESTS_FRAGMENT, deviceRef);

  const { onLoadMore: onLoadMoreDeleteOptions } = useRelayConnectionPagination({
    hasNext: hasNextStorage,
    isLoadingNext: isLoadingStorageNext,
    loadNext: loadNextStorage,
  });

  useSubscription<FilesDeleteTab_fileDeleteRequest_Subscription>(
    useMemo(
      () => ({
        subscription: FILE_DELETE_REQUEST_UPDATED_SUBSCRIPTION,
        variables: { deviceId },
      }),
      [deviceId],
    ),
  );

  const fileDeleteRequests = useMemo(
    () =>
      data.fileDeleteRequests?.edges?.flatMap((edge) =>
        edge?.node ? [edge.node] : [],
      ) ?? [],
    [data.fileDeleteRequests],
  );

  const deleteOptions: StorageSourceOption[] = useMemo(() => {
    const edges = storageData.storageFileDownloadRequests?.edges;
    if (!edges) return [];

    const validRequests: Array<{
      id: string;
      fileName: string;
      requestName: string | null;
    }> = [];
    const fileNameCounts: Record<string, number> = {};

    for (const edge of edges) {
      const node = edge?.node;
      if (node?.id) {
        const fileName = node.fileName ?? node.id;
        fileNameCounts[fileName] = (fileNameCounts[fileName] ?? 0) + 1;
        validRequests.push({
          id: node.id,
          fileName,
          requestName: node.requestName ?? null,
        });
      }
    }

    return validRequests.map(({ id, fileName, requestName }) => {
      const isDuplicate = fileNameCounts[fileName] > 1;
      return {
        value: id,
        label:
          isDuplicate && requestName
            ? `${fileName} (${requestName})`
            : fileName,
      };
    });
  }, [storageData.storageFileDownloadRequests]);

  if (!data.capabilities.includes("FILE_TRANSFER_DELETE")) {
    return null;
  }

  const content = (
    <>
      <div className="mt-3">
        <Alert
          show={!!errorFeedback}
          variant="danger"
          onClose={() => setErrorFeedback(null)}
          dismissible
        >
          {errorFeedback}
        </Alert>

        <Stack direction="vertical" gap={3} className="mt-3">
          <ManualFileDeleteRequestFormWrapper
            setErrorFeedback={setErrorFeedback}
            deviceId={deviceId}
            deleteOptions={deleteOptions}
            onLoadMoreDeleteOptions={onLoadMoreDeleteOptions}
            isOnline={isOnline}
          />
        </Stack>
      </div>

      <hr />

      <div className="mt-4">
        <h5>
          <FormattedMessage
            id="components.DeviceTabs.FilesDeleteTab.requestHistory"
            defaultMessage="Request History"
          />
        </h5>

        <FileDeleteRequestsTable requests={fileDeleteRequests} />
      </div>
    </>
  );

  if (embedded) {
    return content;
  }

  return (
    <Tab
      eventKey="device-files-delete-tab"
      title={intl.formatMessage({
        id: "components.DeviceTabs.FilesDeleteTab.title",
        defaultMessage: "Files Delete",
      })}
    >
      <div className="mt-3">
        <h6>
          <FormattedMessage
            id="components.DeviceTabs.FilesDeleteTab.deleteSource"
            defaultMessage="Delete Source"
          />
        </h6>

        {content}
      </div>
    </Tab>
  );
};

export default FilesDeleteTab;
