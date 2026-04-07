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
  type StorageSourceOption,
  type SourceTypeOption,
} from "@/forms/ManualFileUploadRequestForm";
import type { ManualFileUploadRequestData } from "@/forms/validation";

// We use graphql fields below in table columns configuration
/* eslint-disable relay/unused-fields */
const DEVICE_FILE_UPLOAD_REQUESTS_FRAGMENT = graphql`
  fragment FilesDownloadTab_fileUploadRequests on Device
  @refetchable(queryName: "FilesDownloadTab_PaginationQuery") {
    id
    capabilities
    fileUploadRequests(first: $first, after: $after)
      @connection(key: "FilesDownloadTab_fileUploadRequests") {
      edges {
        node {
          id
          url
          getPresignedUrl
          source
          sourceType
          compression
          progressTracked
          status
          progressPercentage
          responseCode
          responseMessage
          httpHeaders
        }
      }
    }
    storageFileDownloadRequests: fileDownloadRequests(
      first: $first
      after: $after
      filter: { destinationType: { eq: STORAGE } }
    ) {
      edges {
        node {
          pathOnDevice
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
        url
        getPresignedUrl
        source
        sourceType
        compression
        progressTracked
        status
        progressPercentage
        responseCode
        responseMessage
        httpHeaders
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

type ManualFileUploadRequestFormWrapperProps = {
  setErrorFeedback: (feedback: React.ReactNode) => void;
  deviceId: string;
  sourceTypeOptions: SourceTypeOption[];
  storageSourceOptions: StorageSourceOption[];
};

const ManualFileUploadRequestFormWrapper = ({
  setErrorFeedback,
  deviceId,
  sourceTypeOptions,
  storageSourceOptions,
}: ManualFileUploadRequestFormWrapperProps) => {
  const intl = useIntl();
  const [createFileUploadRequest, isCreating] =
    useMutation<FilesDownloadTab_createFileUploadRequest_Mutation>(
      DEVICE_CREATE_FILE_UPLOAD_REQUEST_MUTATION,
    );

  const handleSubmit = useCallback(
    async (values: ManualFileUploadRequestData) => {
      setErrorFeedback(null);

      try {
        const { sourceType, source, compression, progressTracked } = values;

        await new Promise<void>((resolve, reject) => {
          createFileUploadRequest({
            variables: {
              input: {
                deviceId,
                sourceType,
                source,
                compression,
                progressTracked,
              },
            },
            onCompleted(_responseData, errors) {
              if (errors && errors.length > 0) {
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
            onError(error) {
              reject(error);
            },
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
    [createFileUploadRequest, deviceId, intl, setErrorFeedback],
  );

  return (
    <ManualFileUploadRequestForm
      isLoading={isCreating}
      onSubmit={handleSubmit}
      sourceTypeOptions={sourceTypeOptions}
      storageSourceOptions={storageSourceOptions}
    />
  );
};

type FilesDownloadTabProps = {
  deviceRef: FilesDownloadTab_fileUploadRequests$key;
  embedded?: boolean;
};

const FilesDownloadTab = ({
  deviceRef,
  embedded = false,
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
    () => data.fileUploadRequests?.edges?.map((edge) => edge.node) ?? [],
    [data.fileUploadRequests],
  );

  const sourceTypeOptions: SourceTypeOption[] = [
    { value: "STORAGE", label: "Storage" },
    { value: "FILESYSTEM", label: "File System" },
  ];

  const storageSourceOptions: StorageSourceOption[] = useMemo(() => {
    const uniqueStorageIds = new Map<string, string>();

    data.storageFileDownloadRequests?.edges?.forEach((edge) => {
      const request = edge?.node;

      if (!request) {
        return;
      }

      const storageId = request.pathOnDevice?.trim();

      if (!storageId || uniqueStorageIds.has(storageId)) {
        return;
      }

      const label = request.fileName
        ? `${request.fileName} (${storageId})`
        : storageId;

      uniqueStorageIds.set(storageId, label);
    });

    return Array.from(uniqueStorageIds.entries()).map(([value, label]) => ({
      value,
      label,
    }));
  }, [data.storageFileDownloadRequests]);

  if (!data.capabilities.includes("FILE_TRANSFER_READ")) {
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
            sourceTypeOptions={sourceTypeOptions}
            storageSourceOptions={storageSourceOptions}
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

        <FileUploadRequestsTable
          requests={fileUploadRequests}
          setErrorFeedback={setErrorFeedback}
        />
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
        id: "components.DeviceTabs.FilesDownloadTab",
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
