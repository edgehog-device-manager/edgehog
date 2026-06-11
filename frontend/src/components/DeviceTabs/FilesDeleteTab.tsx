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

import type { FilesDeleteTab_PaginationQuery } from "@/api/__generated__/FilesDeleteTab_PaginationQuery.graphql";
import type { FilesDeleteTab_createFileDeleteRequest_Mutation } from "@/api/__generated__/FilesDeleteTab_createFileDeleteRequest_Mutation.graphql";
import type { FilesDeleteTab_deviceFiles$key } from "@/api/__generated__/FilesDeleteTab_deviceFiles.graphql";
import type { FilesDeleteTab_deviceFiles_PaginationQuery } from "@/api/__generated__/FilesDeleteTab_deviceFiles_PaginationQuery.graphql";
import type { FilesDeleteTab_fileDeleteRequest_Subscription } from "@/api/__generated__/FilesDeleteTab_fileDeleteRequest_Subscription.graphql";
import type { FilesDeleteTab_fileManagement$key } from "@/api/__generated__/FilesDeleteTab_fileManagement.graphql";

import Alert from "@/components/Alert";
import FileDeleteRequestsTable from "@/components/FileDeleteRequestsTable";
import Stack from "@/components/Stack";
import { Tab } from "@/components/Tabs";
import ManualFileDeleteRequestForm, {
  type ManualFileDeleteRequestFormValues,
  type StorageSourceOption,
} from "@/forms/ManualFileDeleteRequestForm";
import useRelayConnectionPagination from "@/hooks/useRelayConnectionPagination";

// We use graphql fields below in table columns configuration
/* eslint-disable relay/unused-fields */
const DEVICE_FILES_FRAGMENT = graphql`
  fragment FilesDeleteTab_fileManagement on Device
  @refetchable(queryName: "FilesDeleteTab_PaginationQuery") {
    capabilities
    fileDeleteRequests(
      first: $first
      after: $after
      sort: [{ field: UPDATED_AT, order: DESC }]
    ) @connection(key: "FilesDeleteTab_fileDeleteRequests") {
      edges {
        node {
          force
          status
          responseCode
          responseMessages
          deviceFile {
            fileId
            pathOnDevice
            fileDownloadRequest {
              fileName
            }
          }
        }
      }
    }
  }
`;

const DEVICE_DEVICE_FILES_FRAGMENT = graphql`
  fragment FilesDeleteTab_deviceFiles on Device
  @refetchable(queryName: "FilesDeleteTab_deviceFiles_PaginationQuery")
  @argumentDefinitions(first: { type: "Int" }, after: { type: "String" }) {
    deviceFiles(
      first: $first
      after: $after
      filter: { deleted: { eq: false } }
    ) @connection(key: "FilesDeleteTab_deviceFiles") {
      edges {
        node {
          id
          fileId
          pathOnDevice
          sizeBytes
          fileDownloadRequest {
            id
            fileName
          }
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
        deviceFile {
          fileId
          pathOnDevice
          fileDownloadRequest {
            fileName
          }
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
        deviceFile {
          fileId
          pathOnDevice
          fileDownloadRequest {
            fileName
          }
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
                deviceFileId: values.deviceFileId,
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
                { sort: [{ field: "UPDATED_AT", order: "DESC" }] },
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
  deviceRef: FilesDeleteTab_fileManagement$key & FilesDeleteTab_deviceFiles$key;
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
    data: deviceFilesData,
    loadNext: loadNextDeviceFiles,
    hasNext: hasNextDeviceFiles,
    isLoadingNext: isLoadingDeviceFilesNext,
  } = usePaginationFragment<
    FilesDeleteTab_deviceFiles_PaginationQuery,
    FilesDeleteTab_deviceFiles$key
  >(DEVICE_DEVICE_FILES_FRAGMENT, deviceRef);

  const { onLoadMore: onLoadMoreDeleteOptions } = useRelayConnectionPagination({
    hasNext: hasNextDeviceFiles,
    isLoadingNext: isLoadingDeviceFilesNext,
    loadNext: loadNextDeviceFiles,
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

  const deleteOptions = useMemo<StorageSourceOption[]>(() => {
    const edges = deviceFilesData?.deviceFiles?.edges;
    if (!edges || edges.length === 0) return [];

    const fileNameCounts: Record<string, number> = {};

    for (const edge of edges) {
      const node = edge?.node;
      if (!node) continue;

      const fileName = node.fileDownloadRequest?.fileName ?? node.fileId;
      if (fileName) {
        fileNameCounts[fileName] = (fileNameCounts[fileName] ?? 0) + 1;
      }
    }

    const options: StorageSourceOption[] = [];

    for (const edge of edges) {
      const node = edge?.node;
      if (!node) continue;

      const fileId = node.fileId;
      const fileName = node.fileDownloadRequest?.fileName ?? fileId;
      const isDuplicate = fileName ? fileNameCounts[fileName] > 1 : false;

      options.push({
        value: node.id,
        label:
          isDuplicate && fileId && fileName !== fileId
            ? `${fileName} (${fileId})`
            : (fileName ?? fileId),
      });
    }

    return options;
  }, [deviceFilesData?.deviceFiles]);

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
