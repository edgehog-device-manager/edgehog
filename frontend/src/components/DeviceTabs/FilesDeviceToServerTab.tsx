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
import { Card } from "react-bootstrap";
import { FormattedMessage, useIntl } from "react-intl";
import {
  ConnectionHandler,
  graphql,
  useMutation,
  usePaginationFragment,
  useSubscription,
} from "react-relay/hooks";
import { useParams } from "react-router-dom";

import type { FilesDeviceToServerTab_PaginationQuery } from "@/api/__generated__/FilesDeviceToServerTab_PaginationQuery.graphql";
import type { FilesDeviceToServerTab_createFileUploadRequest_Mutation } from "@/api/__generated__/FilesDeviceToServerTab_createFileUploadRequest_Mutation.graphql";
import type { FilesDeviceToServerTab_deviceFiles$key } from "@/api/__generated__/FilesDeviceToServerTab_deviceFiles.graphql";
import type { FilesDeviceToServerTab_deviceFiles_PaginationQuery } from "@/api/__generated__/FilesDeviceToServerTab_deviceFiles_PaginationQuery.graphql";
import type { FilesDeviceToServerTab_fileUploadRequest_updated_Subscription } from "@/api/__generated__/FilesDeviceToServerTab_fileUploadRequest_updated_Subscription.graphql";
import type { FilesDeviceToServerTab_fileUploadRequests$key } from "@/api/__generated__/FilesDeviceToServerTab_fileUploadRequests.graphql";

import Alert from "@/components/Alert";
import FilesDeviceToServerTable from "@/components/FilesDeviceToServerTable";
import Stack from "@/components/Stack";
import { Tab } from "@/components/Tabs";
import ManualFilesDeviceToServerForm, {
  type SourceTypeOption,
  type StorageSourceOption,
} from "@/forms/ManualFilesDeviceToServerForm";
import type {
  FileSourceType,
  ManualFileUploadRequestData,
} from "@/forms/validation";
import useRelayConnectionPagination from "@/hooks/useRelayConnectionPagination";

// We use graphql fields below in table columns configuration
/* eslint-disable relay/unused-fields */
const DEVICE_FILE_UPLOAD_REQUESTS_FRAGMENT = graphql`
  fragment FilesDeviceToServerTab_fileUploadRequests on Device
  @refetchable(queryName: "FilesDeviceToServerTab_PaginationQuery") {
    capabilities
    fileTransferCapabilities {
      unixPermissions
      deviceToServer {
        storage
        streaming
        filesystem
      }
    }
    fileUploadRequests(
      first: $first
      after: $after
      sort: [{ field: UPDATED_AT, order: DESC }]
    ) @connection(key: "FilesDeviceToServerTab_fileUploadRequests") {
      edges {
        node {
          getPresignedUrl
          source
          sourceType
          encoding
          progressTracked
          status
          progressPercentage
          responseCode
          responseMessage
        }
      }
    }
  }
`;

const DEVICE_FILES_FRAGMENT = graphql`
  fragment FilesDeviceToServerTab_deviceFiles on Device
  @refetchable(queryName: "FilesDeviceToServerTab_deviceFiles_PaginationQuery")
  @argumentDefinitions(first: { type: "Int" }, after: { type: "String" }) {
    deviceFiles(
      first: $first
      after: $after
      filter: { deleted: { eq: false } }
    ) @connection(key: "FilesDeviceToServerTab_deviceFiles") {
      edges {
        node {
          id
          fileId
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

const DEVICE_CREATE_FILE_UPLOAD_REQUEST_MUTATION = graphql`
  mutation FilesDeviceToServerTab_createFileUploadRequest_Mutation(
    $input: CreateFileUploadRequestInput!
  ) {
    createFileUploadRequest(input: $input) {
      result {
        id
        getPresignedUrl
        source
        sourceType
        encoding
        progressTracked
        status
        progressPercentage
        responseCode
        responseMessage
      }
    }
  }
`;

const FILE_UPLOAD_REQUEST_UPDATED_SUBSCRIPTION = graphql`
  subscription FilesDeviceToServerTab_fileUploadRequest_updated_Subscription(
    $deviceId: ID!
  ) {
    fileUploadRequestsByDevice(deviceId: $deviceId) {
      updated {
        id
        status
        progressPercentage
        responseCode
        responseMessage
      }
    }
  }
`;

const normalizeEncodings = (
  encodings: readonly (string | null)[] | null | undefined,
): string[] => {
  if (!encodings) return [];
  return encodings
    .map((e) => e?.trim())
    .filter((e): e is string => e != null && e.length > 0);
};

type ManualFilesDeviceToServerFormWrapperProps = {
  setErrorFeedback: (feedback: React.ReactNode) => void;
  deviceId: string;
  supportedEncodingsBySourceType: Record<FileSourceType, string[]>;
  sourceTypeOptions: SourceTypeOption[];
  storageSourceOptions: StorageSourceOption[];
  onLoadMoreStorageOptions?: () => void;
  isOnline: boolean;
};

const ManualFilesDeviceToServerFormWrapper = ({
  setErrorFeedback,
  deviceId,
  supportedEncodingsBySourceType,
  sourceTypeOptions,
  storageSourceOptions,
  onLoadMoreStorageOptions,
  isOnline,
}: ManualFilesDeviceToServerFormWrapperProps) => {
  const intl = useIntl();
  const [createFileUploadRequest, isCreating] =
    useMutation<FilesDeviceToServerTab_createFileUploadRequest_Mutation>(
      DEVICE_CREATE_FILE_UPLOAD_REQUEST_MUTATION,
    );

  const handleSubmit = useCallback(
    async (values: ManualFileUploadRequestData) => {
      if (!isOnline) {
        setErrorFeedback(
          <FormattedMessage
            id="components.DeviceTabs.FilesDeviceToServerTab.deviceOfflineError"
            defaultMessage="The device is disconnected. You cannot transfer files while it is offline."
          />,
        );
        return;
      }

      setErrorFeedback(null);

      try {
        const { sourceType, source, encoding, progressTracked } = values;

        await new Promise<void>((resolve, reject) => {
          createFileUploadRequest({
            variables: {
              input: {
                deviceId,
                sourceType,
                deviceFileId: sourceType === "STORAGE" ? source : undefined,
                fileSystemPath:
                  sourceType === "FILESYSTEM" ? source : undefined,
                encoding,
                progressTracked,
              },
            },
            onCompleted(_responseData, errors) {
              if (errors?.length) {
                reject(
                  new Error(
                    errors
                      .map(({ fields, message }) =>
                        fields?.length
                          ? `${fields.join(" ")} ${message}`
                          : message,
                      )
                      .join(". \n"),
                  ),
                );
                return;
              }

              resolve();
            },
            updater(store, data) {
              const newRequestId = data?.createFileUploadRequest?.result?.id;
              if (!newRequestId) return;
              const newRequest = store.get(newRequestId);
              const storedDevice = store.get(deviceId);
              if (!storedDevice || !newRequest) return;

              const connection = ConnectionHandler.getConnection(
                storedDevice,
                "FilesDeviceToServerTab_fileUploadRequests",
                { sort: [{ field: "UPDATED_AT", order: "DESC" }] },
              );
              if (!connection) return;

              const edges = connection.getLinkedRecords("edges") ?? [];
              const alreadyPresent = edges.some(
                (edge) =>
                  edge.getLinkedRecord("node")?.getDataID() === newRequestId,
              );
              if (alreadyPresent) return;

              const edge = ConnectionHandler.createEdge(
                store,
                connection,
                newRequest,
                "FileUploadRequestEdge",
              );
              ConnectionHandler.insertEdgeBefore(connection, edge);
            },
            onError: reject,
          });
        });
      } catch (error) {
        const message =
          error instanceof Error
            ? error.message
            : intl.formatMessage({
                id: "components.DeviceTabs.FilesDeviceToServerTab.error.unknownError",
                defaultMessage: "An unknown error occurred.",
              });

        setErrorFeedback(message);
      }
    },
    [createFileUploadRequest, deviceId, intl, setErrorFeedback, isOnline],
  );

  return (
    <ManualFilesDeviceToServerForm
      isLoading={isCreating}
      onSubmit={handleSubmit}
      supportedEncodingsBySourceType={supportedEncodingsBySourceType}
      sourceTypeOptions={sourceTypeOptions}
      storageSourceOptions={storageSourceOptions}
      onLoadMoreStorageOptions={onLoadMoreStorageOptions}
    />
  );
};

type FilesDeviceToServerTabProps = {
  deviceRef: FilesDeviceToServerTab_fileUploadRequests$key &
    FilesDeviceToServerTab_deviceFiles$key;
  embedded?: boolean;
  isOnline?: boolean;
};

const FilesDeviceToServerTab = ({
  deviceRef,
  embedded = false,
  isOnline = false,
}: FilesDeviceToServerTabProps) => {
  const intl = useIntl();
  const { deviceId = "" } = useParams();

  const [errorFeedback, setErrorFeedback] = useState<React.ReactNode>(null);

  const { data } = usePaginationFragment<
    FilesDeviceToServerTab_PaginationQuery,
    FilesDeviceToServerTab_fileUploadRequests$key
  >(DEVICE_FILE_UPLOAD_REQUESTS_FRAGMENT, deviceRef);

  const {
    data: deviceFilesData,
    loadNext: loadNextDeviceFiles,
    hasNext: hasNextDeviceFiles,
    isLoadingNext: isLoadingDeviceFilesNext,
  } = usePaginationFragment<
    FilesDeviceToServerTab_deviceFiles_PaginationQuery,
    FilesDeviceToServerTab_deviceFiles$key
  >(DEVICE_FILES_FRAGMENT, deviceRef);

  const { onLoadMore: onLoadMoreStorageOptions } = useRelayConnectionPagination(
    {
      hasNext: hasNextDeviceFiles,
      isLoadingNext: isLoadingDeviceFilesNext,
      loadNext: loadNextDeviceFiles,
    },
  );

  useSubscription<FilesDeviceToServerTab_fileUploadRequest_updated_Subscription>(
    useMemo(
      () => ({
        subscription: FILE_UPLOAD_REQUEST_UPDATED_SUBSCRIPTION,
        variables: { deviceId },
      }),
      [deviceId],
    ),
  );

  const fileUploadRequests = useMemo(
    () =>
      data.fileUploadRequests?.edges?.flatMap((edge) =>
        edge?.node ? [edge.node] : [],
      ) ?? [],
    [data.fileUploadRequests],
  );

  const sourceTypeOptions = useMemo<SourceTypeOption[]>(() => {
    const capabilities = data.fileTransferCapabilities?.deviceToServer;

    if (!capabilities) {
      return [];
    }

    const options: SourceTypeOption[] = [];

    if (capabilities.storage != null) {
      options.push({
        value: "STORAGE",
        label: intl.formatMessage({
          id: "components.DeviceTabs.FilesDeviceToServerTab.sourceType.storage",
          defaultMessage: "Storage",
        }),
      });
    }

    if (capabilities.filesystem != null) {
      options.push({
        value: "FILESYSTEM",
        label: intl.formatMessage({
          id: "components.DeviceTabs.FilesDeviceToServerTab.sourceType.filesystem",
          defaultMessage: "File System",
        }),
      });
    }

    // STEAMING capability is currently not supported as source type for uploads,
    // as it is not clear how it should be handled on the frontend.

    return options;
  }, [data.fileTransferCapabilities?.deviceToServer, intl]);

  const storageSourceOptions = useMemo<StorageSourceOption[]>(() => {
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

  const supportedEncodingsBySourceType = useMemo<
    Record<FileSourceType, string[]>
  >(() => {
    const capabilities = data.fileTransferCapabilities?.deviceToServer;

    if (!capabilities) {
      return { STORAGE: [], FILESYSTEM: [] };
    }

    return {
      STORAGE: normalizeEncodings(capabilities.storage),
      FILESYSTEM: normalizeEncodings(capabilities.filesystem),
    };
  }, [data.fileTransferCapabilities?.deviceToServer]);

  if (
    !data.capabilities.includes("FILE_TRANSFER_READ") ||
    sourceTypeOptions.length === 0
  ) {
    return null;
  }

  const content = (
    <>
      <Card className="h-100 border-0 p-3 shadow-sm mb-3">
        <Alert
          show={!!errorFeedback}
          variant="danger"
          onClose={() => setErrorFeedback(null)}
          dismissible
        >
          {errorFeedback}
        </Alert>

        <Stack direction="vertical" gap={3} className="mt-3">
          <ManualFilesDeviceToServerFormWrapper
            setErrorFeedback={setErrorFeedback}
            deviceId={deviceId}
            supportedEncodingsBySourceType={supportedEncodingsBySourceType}
            sourceTypeOptions={sourceTypeOptions}
            storageSourceOptions={storageSourceOptions}
            onLoadMoreStorageOptions={onLoadMoreStorageOptions}
            isOnline={isOnline}
          />
        </Stack>
      </Card>

      <hr />

      <Card className="gap-2 border-0 shadow-sm flex-grow-1 p-4">
        <h5>
          <FormattedMessage
            id="components.DeviceTabs.FilesDeviceToServerTab.requestHistory"
            defaultMessage="Request History"
          />
        </h5>

        <FilesDeviceToServerTable requests={fileUploadRequests} />
      </Card>
    </>
  );

  if (embedded) {
    return content;
  }

  return (
    <Tab
      eventKey="device-files-download-tab"
      title={intl.formatMessage({
        id: "components.DeviceTabs.FilesDeviceToServerTab.title",
        defaultMessage: "Files Download",
      })}
    >
      <div className="mt-3">
        <h6>
          <FormattedMessage
            id="components.DeviceTabs.FilesDeviceToServerTab.uploadSource"
            defaultMessage="Upload Source"
          />
        </h6>
        {content}
      </div>
    </Tab>
  );
};

export default FilesDeviceToServerTab;
