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

import type { FilesDownloadTab_PaginationQuery } from "@/api/__generated__/FilesDownloadTab_PaginationQuery.graphql";
import type { FilesDownloadTab_createFileUploadRequest_Mutation } from "@/api/__generated__/FilesDownloadTab_createFileUploadRequest_Mutation.graphql";
import type { FilesDownloadTab_fileUploadRequest_updated_Subscription } from "@/api/__generated__/FilesDownloadTab_fileUploadRequest_updated_Subscription.graphql";
import type { FilesDownloadTab_fileUploadRequests$key } from "@/api/__generated__/FilesDownloadTab_fileUploadRequests.graphql";

import Alert from "@/components/Alert";
import FileUploadRequestsTable from "@/components/FileUploadRequestsTable";
import Stack from "@/components/Stack";
import { Tab } from "@/components/Tabs";
import ManualFileUploadRequestForm, {
  type SourceTypeOption,
  type StorageSourceOption,
} from "@/forms/ManualFileUploadRequestForm";
import type {
  FileSourceType,
  ManualFileUploadRequestData,
} from "@/forms/validation";

// We use graphql fields below in table columns configuration
/* eslint-disable relay/unused-fields */
const DEVICE_FILE_UPLOAD_REQUESTS_FRAGMENT = graphql`
  fragment FilesDownloadTab_fileUploadRequests on Device
  @refetchable(queryName: "FilesDownloadTab_PaginationQuery") {
    capabilities
    fileTransferCapabilities {
      unixPermissions
      deviceToServer {
        storage
        streaming
        filesystem
      }
    }
    fileUploadRequests(first: $first, after: $after)
      @connection(key: "FilesDownloadTab_fileUploadRequests") {
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
    storageFileDownloadRequests: fileDownloadRequests(
      filter: {
        destinationType: { eq: STORAGE }
        status: { eq: COMPLETED }
        deleted: { eq: false }
      }
    ) {
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
  mutation FilesDownloadTab_createFileUploadRequest_Mutation(
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
  subscription FilesDownloadTab_fileUploadRequest_updated_Subscription(
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

type ManualFileUploadRequestFormWrapperProps = {
  setErrorFeedback: (feedback: React.ReactNode) => void;
  deviceId: string;
  supportedEncodingsBySourceType: Record<FileSourceType, string[]>;
  sourceTypeOptions: SourceTypeOption[];
  storageSourceOptions: StorageSourceOption[];
  isOnline: boolean;
};

const ManualFileUploadRequestFormWrapper = ({
  setErrorFeedback,
  deviceId,
  supportedEncodingsBySourceType,
  sourceTypeOptions,
  storageSourceOptions,
  isOnline,
}: ManualFileUploadRequestFormWrapperProps) => {
  const intl = useIntl();
  const [createFileUploadRequest, isCreating] =
    useMutation<FilesDownloadTab_createFileUploadRequest_Mutation>(
      DEVICE_CREATE_FILE_UPLOAD_REQUEST_MUTATION,
    );

  const handleSubmit = useCallback(
    async (values: ManualFileUploadRequestData) => {
      if (!isOnline) {
        setErrorFeedback(
          <FormattedMessage
            id="components.DeviceTabs.FilesDownloadTab.deviceOfflineError"
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
                "FilesDownloadTab_fileUploadRequests",
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
                id: "components.DeviceTabs.FilesDownloadTab.error.unknownError",
                defaultMessage: "An unknown error occurred.",
              });

        setErrorFeedback(message);
      }
    },
    [createFileUploadRequest, deviceId, intl, setErrorFeedback, isOnline],
  );

  return (
    <ManualFileUploadRequestForm
      isLoading={isCreating}
      onSubmit={handleSubmit}
      supportedEncodingsBySourceType={supportedEncodingsBySourceType}
      sourceTypeOptions={sourceTypeOptions}
      storageSourceOptions={storageSourceOptions}
    />
  );
};

type FilesDownloadTabProps = {
  deviceRef: FilesDownloadTab_fileUploadRequests$key;
  embedded?: boolean;
  isOnline?: boolean;
};

const FilesDownloadTab = ({
  deviceRef,
  embedded = false,
  isOnline = false,
}: FilesDownloadTabProps) => {
  const intl = useIntl();
  const { deviceId = "" } = useParams();

  const [errorFeedback, setErrorFeedback] = useState<React.ReactNode>(null);

  const { data } = usePaginationFragment<
    FilesDownloadTab_PaginationQuery,
    FilesDownloadTab_fileUploadRequests$key
  >(DEVICE_FILE_UPLOAD_REQUESTS_FRAGMENT, deviceRef);

  useSubscription<FilesDownloadTab_fileUploadRequest_updated_Subscription>(
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
      data.fileUploadRequests?.edges
        ?.map((edge) => edge?.node)
        .filter(Boolean) ?? [],
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
          id: "components.DeviceTabs.FilesDownloadTab.sourceType.storage",
          defaultMessage: "Storage",
        }),
      });
    }

    if (capabilities.filesystem != null) {
      options.push({
        value: "FILESYSTEM",
        label: intl.formatMessage({
          id: "components.DeviceTabs.FilesDownloadTab.sourceType.filesystem",
          defaultMessage: "File System",
        }),
      });
    }

    // STEAMING capability is currently not supported as source type for uploads,
    // as it is not clear how it should be handled on the frontend.

    return options;
  }, [data.fileTransferCapabilities?.deviceToServer, intl]);

  const storageSourceOptions = useMemo<StorageSourceOption[]>(() => {
    const edges = data.storageFileDownloadRequests?.edges;
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
  }, [data.storageFileDownloadRequests]);

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
          <ManualFileUploadRequestFormWrapper
            setErrorFeedback={setErrorFeedback}
            deviceId={deviceId}
            supportedEncodingsBySourceType={supportedEncodingsBySourceType}
            sourceTypeOptions={sourceTypeOptions}
            storageSourceOptions={storageSourceOptions}
            isOnline={isOnline}
          />
        </Stack>
      </div>

      <hr />

      <div className="mt-4">
        <h5>
          <FormattedMessage
            id="components.DeviceTabs.FilesDownloadTab.requestHistory"
            defaultMessage="Request History"
          />
        </h5>

        <FileUploadRequestsTable requests={fileUploadRequests} />
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
        id: "components.DeviceTabs.FilesDownloadTab.title",
        defaultMessage: "Files Download",
      })}
    >
      <div className="mt-3">
        <h6>
          <FormattedMessage
            id="components.DeviceTabs.FilesDownloadTab.uploadSource"
            defaultMessage="Upload Source"
          />
        </h6>
        {content}
      </div>
    </Tab>
  );
};

export default FilesDownloadTab;
