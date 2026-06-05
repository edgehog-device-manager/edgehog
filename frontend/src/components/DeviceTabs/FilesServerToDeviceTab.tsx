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

import React, {
  Suspense,
  useCallback,
  useEffect,
  useMemo,
  useState,
} from "react";
import { ToggleButton, ToggleButtonGroup } from "react-bootstrap";
import { FormattedMessage, useIntl } from "react-intl";
import type { PreloadedQuery } from "react-relay/hooks";
import {
  ConnectionHandler,
  graphql,
  useMutation,
  usePaginationFragment,
  usePreloadedQuery,
  useQueryLoader,
  useSubscription,
} from "react-relay/hooks";
import { useParams } from "react-router-dom";
import { PayloadError } from "relay-runtime";

import type { FilesServerToDeviceTab_PaginationQuery } from "@/api/__generated__/FilesServerToDeviceTab_PaginationQuery.graphql";
import type { FilesServerToDeviceTab_createManagedFileDownloadRequest_Mutation } from "@/api/__generated__/FilesServerToDeviceTab_createManagedFileDownloadRequest_Mutation.graphql";
import type {
  CreateManualFileDownloadRequestInput,
  FilesServerToDeviceTab_createManualFileDownloadRequest_Mutation,
  FilesServerToDeviceTab_createManualFileDownloadRequest_Mutation$data,
} from "@/api/__generated__/FilesServerToDeviceTab_createManualFileDownloadRequest_Mutation.graphql";
import type { FilesServerToDeviceTab_fileDownloadRequests$key } from "@/api/__generated__/FilesServerToDeviceTab_fileDownloadRequests.graphql";
import type { FilesServerToDeviceTab_getRepositories_Query } from "@/api/__generated__/FilesServerToDeviceTab_getRepositories_Query.graphql";

import Alert from "@/components/Alert";
import FilesServerToDeviceTable from "@/components/FilesServerToDeviceTable";
import Spinner from "@/components/Spinner";
import Stack from "@/components/Stack";
import { Tab } from "@/components/Tabs";
import { RECORDS_TO_LOAD_FIRST } from "@/constants";
import type { FileDownloadRequestFormValues } from "@/forms/ManualFilesServerToDeviceFileForm";
import ManualFileDownloadRequestForm from "@/forms/ManualFilesServerToDeviceFileForm";
import ManualFilesServerToDeviceRepositoryForm from "@/forms/ManualFilesServerToDeviceRepositoryForm";
import type {
  FileDestinationType,
  ManualFileDownloadRequestFromRepositoryData,
} from "@/forms/validation";
import { prepareUploadFile } from "@/lib/files";

// We use graphql fields below in columns configuration
/* eslint-disable relay/unused-fields */
const DEVICE_FILE_DOWNLOAD_REQUESTS_FRAGMENT = graphql`
  fragment FilesServerToDeviceTab_fileDownloadRequests on Device
  @refetchable(queryName: "FilesServerToDeviceTab_PaginationQuery") {
    fileTransferCapabilities {
      unixPermissions
      serverToDevice {
        storage
        streaming
        filesystem
      }
    }
    fileDownloadRequests(
      first: $first
      after: $after
      sort: [{ field: UPDATED_AT, order: DESC }]
    ) @connection(key: "FilesServerToDeviceTab_fileDownloadRequests") {
      edges {
        node {
          id
          fileName
          requestName
          status
          progressPercentage
          responseCode
          responseMessage
          destinationType
          destination
          pathOnDevice
          progressTracked
          ttlSeconds
          uncompressedFileSizeBytes
          campaignTarget {
            campaign {
              id
              name
            }
          }
        }
      }
    }
  }
`;

const GET_REPOSITORIES_QUERY = graphql`
  query FilesServerToDeviceTab_getRepositories_Query(
    $first: Int
    $after: String
    $filterRepositories: RepositoryFilterInput = {}
  ) {
    ...ManualFilesServerToDeviceRepositoryForm_repositories_Fragment
      @arguments(filter: $filterRepositories)
  }
`;

const DEVICE_CREATE_MANUAL_FILE_DOWNLOAD_REQUEST_MUTATION = graphql`
  mutation FilesServerToDeviceTab_createManualFileDownloadRequest_Mutation(
    $input: CreateManualFileDownloadRequestInput!
  ) {
    createManualFileDownloadRequest(input: $input) {
      result {
        id
        requestName
        url
        fileName
        status
        progressPercentage
        responseCode
        responseMessage
        destinationType
        destination
        pathOnDevice
        progressTracked
        ttlSeconds
        uncompressedFileSizeBytes
      }
    }
  }
`;

const DEVICE_CREATE_MANAGED_FILE_DOWNLOAD_REQUEST_MUTATION = graphql`
  mutation FilesServerToDeviceTab_createManagedFileDownloadRequest_Mutation(
    $input: CreateManagedFileDownloadRequestInput!
  ) {
    createManagedFileDownloadRequest(input: $input) {
      result {
        id
        url
        fileName
        requestName
        status
        progressPercentage
        responseCode
        responseMessage
        destinationType
        destination
        pathOnDevice
        progressTracked
        ttlSeconds
        uncompressedFileSizeBytes
      }
    }
  }
`;

const FILE_DOWNLOAD_REQUEST_UPDATED_SUBSCRIPTION = graphql`
  subscription FilesServerToDeviceTab_fileDownloadRequest_updated_Subscription(
    $deviceId: ID!
  ) {
    fileDownloadRequestsByDevice(deviceId: $deviceId) {
      updated {
        id
        status
        progressPercentage
        responseCode
        responseMessage
        pathOnDevice
      }
    }
  }
`;

type FileDownloadRequest = NonNullable<
  FilesServerToDeviceTab_createManualFileDownloadRequest_Mutation$data["createManualFileDownloadRequest"]
>["result"];

type DestinationTypeOption = {
  value: FileDestinationType;
  label: string;
};

class APIValidationError extends Error {
  constructor(public errors: PayloadError[]) {
    super("API Validation Error");
  }
}

const ARCHIVE_EXTENSIONS = new Set(["tar", "gz", "lz4", "tar.gz", "tar.lz4"]);
const STORAGE_FILE_DOWNLOAD_REQUEST_CONNECTION_KEYS = [
  "FilesDeviceToServerTab_storageFileDownloadRequests",
  "FilesDeleteTab_storageFileDownloadRequests",
] as const;
const STORAGE_FILE_DOWNLOAD_REQUEST_FILTERS = {
  filter: {
    destinationType: { eq: "STORAGE" },
    status: { eq: "COMPLETED" },
    deleted: { eq: false },
  },
} as const;

const formatPayloadErrors = (errors: readonly PayloadError[]): string => {
  return errors
    .map(({ fields, message }) =>
      fields?.length ? `${fields.join(", ")}: ${message}` : message,
    )
    .join(". ");
};

const normalizeEncodings = (
  encodings: readonly (string | null)[] | null | undefined,
): string[] => {
  if (!encodings) return [];
  return encodings
    .map((e) => e?.trim())
    .filter((e): e is string => e != null && e.length > 0);
};

type ManualFileDownloadRequestFormWrapperProps = {
  setErrorFeedback: (feedback: React.ReactNode) => void;
  deviceId: string;
  supportedEncodingsByDestination: Record<FileDestinationType, string[]>;
  allowArchiveUpload: boolean;
  showAdvancedOptions: boolean;
  destinationTypeOptions: DestinationTypeOption[];
  isOnline: boolean;
};

const ManualFileDownloadRequestFormWrapper = ({
  setErrorFeedback,
  deviceId,
  supportedEncodingsByDestination,
  allowArchiveUpload,
  showAdvancedOptions,
  destinationTypeOptions,
  isOnline,
}: ManualFileDownloadRequestFormWrapperProps) => {
  const [isUploading, setIsUploading] = useState(false);

  const [createFileDownloadRequest] =
    useMutation<FilesServerToDeviceTab_createManualFileDownloadRequest_Mutation>(
      DEVICE_CREATE_MANUAL_FILE_DOWNLOAD_REQUEST_MUTATION,
    );

  // Warn user before leaving page during upload
  useEffect(() => {
    const handleBeforeUnload = (event: BeforeUnloadEvent) => {
      if (isUploading) {
        event.preventDefault();
      }
    };

    window.addEventListener("beforeunload", handleBeforeUnload);

    return () => {
      window.removeEventListener("beforeunload", handleBeforeUnload);
    };
  }, [isUploading]);

  const commitDownloadRequest = useCallback(
    (input: CreateManualFileDownloadRequestInput) =>
      new Promise<FileDownloadRequest>((resolve, reject) => {
        createFileDownloadRequest({
          variables: { input },
          onCompleted: (data, errors) => {
            if (errors?.length) {
              return reject(new APIValidationError(errors));
            }
            const result = data?.createManualFileDownloadRequest?.result;
            if (result) {
              resolve(result);
            } else {
              reject(new Error("Mutation succeeded but returned no result."));
            }
          },
          onError: reject,
          updater: (store) => {
            const payload = store.getRootField(
              "createManualFileDownloadRequest",
            );
            const newRequest = payload?.getLinkedRecord("result");
            const storedDevice = store.get(deviceId);

            if (!storedDevice || !newRequest) return;

            const connection = ConnectionHandler.getConnection(
              storedDevice,
              "FilesServerToDeviceTab_fileDownloadRequests",
              { sort: [{ field: "UPDATED_AT", order: "DESC" }] },
            );

            if (connection) {
              const edge = ConnectionHandler.createEdge(
                store,
                connection,
                newRequest,
                "FileDownloadRequestEdge",
              );
              ConnectionHandler.insertEdgeBefore(connection, edge);
            }

            const destinationType = newRequest.getValue("destinationType");
            if (destinationType === "STORAGE") {
              const newRequestId = newRequest.getDataID();

              for (const connectionKey of STORAGE_FILE_DOWNLOAD_REQUEST_CONNECTION_KEYS) {
                const storageConnection = ConnectionHandler.getConnection(
                  storedDevice,
                  connectionKey,
                  STORAGE_FILE_DOWNLOAD_REQUEST_FILTERS,
                );
                if (!storageConnection) continue;

                const edges = storageConnection.getLinkedRecords("edges") ?? [];
                const alreadyPresent = edges.some(
                  (edge) =>
                    edge?.getLinkedRecord("node")?.getDataID() === newRequestId,
                );
                if (alreadyPresent) continue;

                const edge = ConnectionHandler.createEdge(
                  store,
                  storageConnection,
                  newRequest,
                  "FileDownloadRequestEdge",
                );
                ConnectionHandler.insertEdgeBefore(storageConnection, edge);
              }
            }
          },
        });
      }),
    [createFileDownloadRequest, deviceId],
  );

  const handleFileUpload = useCallback(
    async (values: FileDownloadRequestFormValues) => {
      if (!isOnline) {
        setErrorFeedback(
          <FormattedMessage
            id="components.DeviceTabs.FilesServerToDeviceTab.deviceOfflineError"
            defaultMessage="The device is disconnected. You cannot transfer files while it is offline."
          />,
        );
        return;
      }

      const { files, customFileName, ...rest } = values;
      if (!files?.length) return;

      setIsUploading(true);
      setErrorFeedback(null);

      try {
        const { file, fileName, uncompressedSize } = await prepareUploadFile({
          files,
          customFileName,
          encoding: values.encoding,
        });

        await commitDownloadRequest({
          ...rest,
          file,
          fileName,
          uncompressedFileSizeBytes: uncompressedSize,
          deviceId,
        });

        setIsUploading(false);
      } catch (err) {
        setIsUploading(false);
        if (err instanceof APIValidationError) {
          setErrorFeedback(formatPayloadErrors(err.errors));
        } else {
          setErrorFeedback(
            <FormattedMessage
              id="components.DeviceTabs.FilesServerToDeviceTab.uploadErrorFeedback"
              defaultMessage="Upload failed. Please check your connection."
            />,
          );
        }
      }
    },
    [deviceId, commitDownloadRequest, setErrorFeedback, isOnline],
  );

  return (
    <ManualFileDownloadRequestForm
      isLoading={isUploading}
      onFileSubmit={handleFileUpload}
      supportedEncodingsByDestination={supportedEncodingsByDestination}
      allowArchiveUpload={allowArchiveUpload}
      showAdvancedOptions={showAdvancedOptions}
      destinationTypeOptions={destinationTypeOptions}
    />
  );
};

type ManualFilesServerToDeviceRepositoryFormWrapperProps = {
  setErrorFeedback: (feedback: React.ReactNode) => void;
  repositoriesQueryRef: PreloadedQuery<FilesServerToDeviceTab_getRepositories_Query>;
  deviceId: string;
  showAdvancedOptions: boolean;
  destinationTypeOptions: DestinationTypeOption[];
  isOnline: boolean;
};

const ManualFilesServerToDeviceRepositoryFormWrapper = ({
  setErrorFeedback,
  repositoriesQueryRef,
  deviceId,
  showAdvancedOptions,
  destinationTypeOptions,
  isOnline,
}: ManualFilesServerToDeviceRepositoryFormWrapperProps) => {
  const [isUploading, setIsUploading] = useState(false);

  const repositoriesData = usePreloadedQuery(
    GET_REPOSITORIES_QUERY,
    repositoriesQueryRef,
  );

  const [createFileDownloadRequest] =
    useMutation<FilesServerToDeviceTab_createManagedFileDownloadRequest_Mutation>(
      DEVICE_CREATE_MANAGED_FILE_DOWNLOAD_REQUEST_MUTATION,
    );

  const handleFileUpload = useCallback(
    (values: ManualFileDownloadRequestFromRepositoryData) => {
      if (!isOnline) {
        setErrorFeedback(
          <FormattedMessage
            id="components.DeviceTabs.FilesServerToDeviceTab.deviceOfflineError"
            defaultMessage="The device is disconnected. You cannot transfer files while it is offline."
          />,
        );
        return;
      }

      const {
        requestName,
        file,
        destinationType,
        destination,
        ttlSeconds,
        progressTracked,
        fileMode,
        userId,
        groupId,
      } = values;

      setErrorFeedback(null);
      setIsUploading(true);

      createFileDownloadRequest({
        variables: {
          input: {
            requestName,
            deviceId,
            fileId: file.id,
            fileMode,
            userId,
            groupId,
            destinationType,
            destination,
            progressTracked,
            ttlSeconds,
          },
        },
        onCompleted: (_data, errors) => {
          setIsUploading(false);
          if (errors?.length) {
            setErrorFeedback(formatPayloadErrors(errors));
          }
        },
        onError: () => {
          setIsUploading(false);
          setErrorFeedback(
            <FormattedMessage
              id="components.DeviceTabs.FilesServerToDeviceTab.creationErrorFeedback"
              defaultMessage="Could not create file download request, please try again."
            />,
          );
        },
        updater: (store) => {
          const payload = store.getRootField(
            "createManagedFileDownloadRequest",
          );
          const newRequest = payload?.getLinkedRecord("result");
          const storedDevice = store.get(deviceId);

          if (!storedDevice || !newRequest) return;

          const connection = ConnectionHandler.getConnection(
            storedDevice,
            "FilesServerToDeviceTab_fileDownloadRequests",
            { sort: [{ field: "UPDATED_AT", order: "DESC" }] },
          );

          if (connection) {
            const edge = ConnectionHandler.createEdge(
              store,
              connection,
              newRequest,
              "FileDownloadRequestEdge",
            );
            ConnectionHandler.insertEdgeBefore(connection, edge);
          }

          const destinationType = newRequest.getValue("destinationType");
          if (destinationType === "STORAGE") {
            const newRequestId = newRequest.getDataID();

            for (const connectionKey of STORAGE_FILE_DOWNLOAD_REQUEST_CONNECTION_KEYS) {
              const storageConnection = ConnectionHandler.getConnection(
                storedDevice,
                connectionKey,
                STORAGE_FILE_DOWNLOAD_REQUEST_FILTERS,
              );
              if (!storageConnection) continue;

              const edges = storageConnection.getLinkedRecords("edges") ?? [];
              const alreadyPresent = edges.some(
                (edge) =>
                  edge?.getLinkedRecord("node")?.getDataID() === newRequestId,
              );
              if (alreadyPresent) continue;

              const edge = ConnectionHandler.createEdge(
                store,
                storageConnection,
                newRequest,
                "FileDownloadRequestEdge",
              );
              ConnectionHandler.insertEdgeBefore(storageConnection, edge);
            }
          }
        },
      });
    },
    [deviceId, createFileDownloadRequest, setErrorFeedback, isOnline],
  );

  return (
    <ManualFilesServerToDeviceRepositoryForm
      repositoriesData={repositoriesData}
      isLoading={isUploading}
      onFileSubmit={handleFileUpload}
      showAdvancedOptions={showAdvancedOptions}
      destinationTypeOptions={destinationTypeOptions}
    />
  );
};

type FilesServerToDeviceTabProps = {
  deviceRef: FilesServerToDeviceTab_fileDownloadRequests$key;
  embedded?: boolean;
  embeddedMode?: "file" | "repository";
  isOnline?: boolean;
};

const FilesServerToDeviceTab = ({
  deviceRef,
  embedded = false,
  embeddedMode,
  isOnline = false,
}: FilesServerToDeviceTabProps) => {
  const intl = useIntl();
  const { deviceId = "" } = useParams();

  const [updateMode, setUpdateMode] = useState<"repository" | "file">("file");
  const effectiveUpdateMode = embeddedMode ?? updateMode;

  const [errorFeedback, setErrorFeedback] = useState<React.ReactNode>(null);

  const { data } = usePaginationFragment<
    FilesServerToDeviceTab_PaginationQuery,
    FilesServerToDeviceTab_fileDownloadRequests$key
  >(DEVICE_FILE_DOWNLOAD_REQUESTS_FRAGMENT, deviceRef);

  useSubscription(
    useMemo(
      () => ({
        subscription: FILE_DOWNLOAD_REQUEST_UPDATED_SUBSCRIPTION,
        variables: { deviceId },
      }),
      [deviceId],
    ),
  );

  const fileDownloadRequests = useMemo(
    () =>
      data.fileDownloadRequests?.edges?.flatMap((edge) =>
        edge?.node ? [edge.node] : [],
      ) ?? [],
    [data.fileDownloadRequests],
  );

  const [getRepositoriesQuery, getRepositories] =
    useQueryLoader<FilesServerToDeviceTab_getRepositories_Query>(
      GET_REPOSITORIES_QUERY,
    );

  const fetchRepositories = useCallback(
    () =>
      getRepositories(
        { first: RECORDS_TO_LOAD_FIRST },
        { fetchPolicy: "store-and-network" },
      ),
    [getRepositories],
  );

  useEffect(fetchRepositories, [fetchRepositories]);

  const showAdvancedOptions = !!data.fileTransferCapabilities?.unixPermissions;

  const destinationTypeOptions = useMemo<DestinationTypeOption[]>(() => {
    const capabilities = data.fileTransferCapabilities?.serverToDevice;

    if (!capabilities) {
      return [];
    }

    const options: DestinationTypeOption[] = [];

    if (capabilities.storage != null) {
      options.push({
        value: "STORAGE",
        label: intl.formatMessage({
          id: "components.DeviceTabs.FilesServerToDeviceTab.destinationType.storage",
          defaultMessage: "Storage",
        }),
      });
    }

    if (capabilities.streaming != null) {
      options.push({
        value: "STREAMING",
        label: intl.formatMessage({
          id: "components.DeviceTabs.FilesServerToDeviceTab.destinationType.streaming",
          defaultMessage: "Streaming",
        }),
      });
    }

    if (capabilities.filesystem != null) {
      options.push({
        value: "FILESYSTEM",
        label: intl.formatMessage({
          id: "components.DeviceTabs.FilesServerToDeviceTab.destinationType.filesystem",
          defaultMessage: "File System",
        }),
      });
    }

    return options;
  }, [data.fileTransferCapabilities?.serverToDevice, intl]);

  const supportedEncodingsByDestination = useMemo<
    Record<FileDestinationType, string[]>
  >(() => {
    const capabilities = data.fileTransferCapabilities?.serverToDevice;
    if (!capabilities) {
      return { STORAGE: [], STREAMING: [], FILESYSTEM: [] };
    }

    return {
      STORAGE: normalizeEncodings(capabilities.storage),
      STREAMING: normalizeEncodings(capabilities.streaming),
      FILESYSTEM: normalizeEncodings(capabilities.filesystem),
    };
  }, [data.fileTransferCapabilities?.serverToDevice]);

  const allowArchiveUpload = useMemo(() => {
    for (const key in supportedEncodingsByDestination) {
      const encodings =
        supportedEncodingsByDestination[key as FileDestinationType];
      for (const encoding of encodings) {
        if (ARCHIVE_EXTENSIONS.has(encoding.toLowerCase())) {
          return true;
        }
      }
    }
    return false;
  }, [supportedEncodingsByDestination]);

  if (destinationTypeOptions.length === 0) {
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

        <Suspense fallback={<Spinner />}>
          <Stack direction="vertical" gap={3} className="mt-3">
            {embeddedMode == null && (
              <div>
                <ToggleButtonGroup
                  type="radio"
                  name="updateMode"
                  value={updateMode}
                  onChange={setUpdateMode}
                  size="sm"
                >
                  <ToggleButton
                    id="mode-file"
                    value="file"
                    variant={
                      updateMode === "file" ? "primary" : "outline-secondary"
                    }
                    className="fw-medium px-3"
                  >
                    <FormattedMessage
                      id="components.DeviceTabs.FilesServerToDeviceTab.modeFile"
                      defaultMessage="Direct File"
                    />
                  </ToggleButton>

                  <ToggleButton
                    id="mode-collection"
                    value="repository"
                    variant={
                      updateMode === "repository"
                        ? "primary"
                        : "outline-secondary"
                    }
                    className="fw-medium px-3"
                  >
                    <FormattedMessage
                      id="components.DeviceTabs.FilesServerToDeviceTab.modeRepository"
                      defaultMessage="Repository"
                    />
                  </ToggleButton>
                </ToggleButtonGroup>
              </div>
            )}

            {effectiveUpdateMode === "file" ? (
              <ManualFileDownloadRequestFormWrapper
                setErrorFeedback={setErrorFeedback}
                deviceId={deviceId}
                supportedEncodingsByDestination={
                  supportedEncodingsByDestination
                }
                allowArchiveUpload={allowArchiveUpload}
                showAdvancedOptions={showAdvancedOptions}
                destinationTypeOptions={destinationTypeOptions}
                isOnline={isOnline}
              />
            ) : (
              getRepositoriesQuery && (
                <ManualFilesServerToDeviceRepositoryFormWrapper
                  repositoriesQueryRef={getRepositoriesQuery}
                  setErrorFeedback={setErrorFeedback}
                  deviceId={deviceId}
                  showAdvancedOptions={showAdvancedOptions}
                  destinationTypeOptions={destinationTypeOptions}
                  isOnline={isOnline}
                />
              )
            )}
          </Stack>
        </Suspense>
      </div>

      <hr />

      <div className="mt-4">
        <h5>
          <FormattedMessage
            id="components.DeviceTabs.FilesServerToDeviceTab.requestHistory"
            defaultMessage="Request History"
          />
        </h5>

        <FilesServerToDeviceTable requests={fileDownloadRequests} />
      </div>
    </>
  );

  if (embedded) {
    return content;
  }

  return (
    <Tab
      eventKey="device-files-upload-tab"
      title={intl.formatMessage({
        id: "components.DeviceTabs.FilesServerToDeviceTab.title",
        defaultMessage: "Files Upload",
      })}
    >
      <div className="mt-3">
        <h5>
          <FormattedMessage
            id="components.DeviceTabs.FilesServerToDeviceTab.uploadLocation"
            defaultMessage="Upload Location"
          />
        </h5>
        {content}
      </div>
    </Tab>
  );
};

export type { DestinationTypeOption };

export default FilesServerToDeviceTab;
