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
import useRelayConnectionPagination from "@/hooks/useRelayConnectionPagination";

import type { FilesDeviceToServerTab_PaginationQuery } from "@/api/__generated__/FilesDeviceToServerTab_PaginationQuery.graphql";
import type { FilesDeviceToServerTab_createFileUploadRequest_Mutation } from "@/api/__generated__/FilesDeviceToServerTab_createFileUploadRequest_Mutation.graphql";
import type { FilesDeviceToServerTab_fileUploadRequest_updated_Subscription } from "@/api/__generated__/FilesDeviceToServerTab_fileUploadRequest_updated_Subscription.graphql";
import type { FilesDeviceToServerTab_fileUploadRequests$key } from "@/api/__generated__/FilesDeviceToServerTab_fileUploadRequests.graphql";
import type { FilesDeviceToServerTab_storageFileDownloadRequests_PaginationQuery } from "@/api/__generated__/FilesDeviceToServerTab_storageFileDownloadRequests_PaginationQuery.graphql";
import type { FilesDeviceToServerTab_storageFileDownloadRequests$key } from "@/api/__generated__/FilesDeviceToServerTab_storageFileDownloadRequests.graphql";

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

const DEVICE_STORAGE_FILE_DOWNLOAD_REQUESTS_FRAGMENT = graphql`
  fragment FilesDeviceToServerTab_storageFileDownloadRequests on Device
  @refetchable(
    queryName: "FilesDeviceToServerTab_storageFileDownloadRequests_PaginationQuery"
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
    ) @connection(key: "FilesDeviceToServerTab_storageFileDownloadRequests") {
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
                source,
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
    FilesDeviceToServerTab_storageFileDownloadRequests$key;
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
    data: storageData,
    loadNext: loadNextStorage,
    hasNext: hasNextStorage,
    isLoadingNext: isLoadingStorageNext,
  } = usePaginationFragment<
    FilesDeviceToServerTab_storageFileDownloadRequests_PaginationQuery,
    FilesDeviceToServerTab_storageFileDownloadRequests$key
  >(DEVICE_STORAGE_FILE_DOWNLOAD_REQUESTS_FRAGMENT, deviceRef);

  const { onLoadMore: onLoadMoreStorageOptions } = useRelayConnectionPagination(
    {
      hasNext: hasNextStorage,
      isLoadingNext: isLoadingStorageNext,
      loadNext: loadNextStorage,
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
      </div>

      <hr />

      <div className="mt-4">
        <h5>
          <FormattedMessage
            id="components.DeviceTabs.FilesDeviceToServerTab.requestHistory"
            defaultMessage="Request History"
          />
        </h5>

        <FilesDeviceToServerTable requests={fileUploadRequests} />
      </div>
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
