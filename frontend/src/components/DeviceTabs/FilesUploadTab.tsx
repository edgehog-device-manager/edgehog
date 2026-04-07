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
import { v7 as uuidv7 } from "uuid";

import type { FilesUploadTab_PaginationQuery } from "@/api/__generated__/FilesUploadTab_PaginationQuery.graphql";
import type { FilesUploadTab_createFileDownloadRequestPresignedUrl_Mutation } from "@/api/__generated__/FilesUploadTab_createFileDownloadRequestPresignedUrl_Mutation.graphql";
import type { FilesUploadTab_createManualFileDownloadRequest_Mutation } from "@/api/__generated__/FilesUploadTab_createManualFileDownloadRequest_Mutation.graphql";
import type { FilesUploadTab_createManagedFileDownloadRequest_Mutation } from "@/api/__generated__/FilesUploadTab_createManagedFileDownloadRequest_Mutation.graphql";
import type { FilesUploadTab_fileDownloadRequests$key } from "@/api/__generated__/FilesUploadTab_fileDownloadRequests.graphql";
import type { FilesUploadTab_getRepositories_Query } from "@/api/__generated__/FilesUploadTab_getRepositories_Query.graphql";

import Alert from "@/components/Alert";
import FileDownloadRequestsTable from "@/components/FileDownloadRequestsTable";
import Spinner from "@/components/Spinner";
import Stack from "@/components/Stack";
import { Tab } from "@/components/Tabs";
import { RECORDS_TO_LOAD_FIRST } from "@/constants";
import type { FileDownloadRequestFormValues } from "@/forms/ManualFileDownloadRequestForm";
import ManualFileDownloadRequestForm from "@/forms/ManualFileDownloadRequestForm";
import ManualFileDownloadRequestFromRepositoryForm from "@/forms/ManualFileDownloadRequestFromRepositoryForm";
import type {
  FileDestinationType,
  ManualFileDownloadRequestFromRepositoryData,
} from "@/forms/validation";
import { computeDigest, createTarGzArchive } from "@/lib/files";

// We use graphql fields below in columns configuration
/* eslint-disable relay/unused-fields */
const DEVICE_FILE_DOWNLOAD_REQUESTS_FRAGMENT = graphql`
  fragment FilesUploadTab_fileDownloadRequests on Device
  @refetchable(queryName: "FilesUploadTab_PaginationQuery") {
    id
    capabilities
    fileDownloadRequests(first: $first, after: $after)
      @connection(key: "FilesUploadTab_fileDownloadRequests") {
      edges {
        node {
          id
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
          digest
          fileMode
          userId
          groupId
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
  query FilesUploadTab_getRepositories_Query(
    $first: Int
    $after: String
    $filterRepositories: RepositoryFilterInput = {}
  ) {
    ...ManualFileDownloadRequestFromRepositoryForm_repositories_Fragment
      @arguments(filter: $filterRepositories)
  }
`;

const DEVICE_GET_PRESIGNED_URL_MUTATION = graphql`
  mutation FilesUploadTab_createFileDownloadRequestPresignedUrl_Mutation(
    $input: CreateFileDownloadRequestPresignedUrlInput!
  ) {
    createFileDownloadRequestPresignedUrl(input: $input)
  }
`;

const DEVICE_CREATE_MANUAL_FILE_DOWNLOAD_REQUEST_MUTATION = graphql`
  mutation FilesUploadTab_createManualFileDownloadRequest_Mutation(
    $input: CreateManualFileDownloadRequestInput!
  ) {
    createManualFileDownloadRequest(input: $input) {
      result {
        id
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
        digest
        fileMode
        userId
        groupId
        uncompressedFileSizeBytes
      }
    }
  }
`;

const DEVICE_CREATE_MANAGED_FILE_DOWNLOAD_REQUEST_MUTATION = graphql`
  mutation FilesUploadTab_createManagedFileDownloadRequest_Mutation(
    $input: CreateManagedFileDownloadRequestInput!
  ) {
    createManagedFileDownloadRequest(input: $input) {
      result {
        id
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
        digest
        fileMode
        userId
        groupId
        uncompressedFileSizeBytes
      }
    }
  }
`;

const FILE_DOWNLOAD_REQUEST_UPDATED_SUBSCRIPTION = graphql`
  subscription FilesUploadTab_fileDownloadRequest_updated_Subscription(
    $deviceId: ID!
  ) {
    fileDownloadRequestsByDevice(deviceId: $deviceId) {
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

type DestinationTypeOption = {
  value: FileDestinationType;
  label: string;
};

const formatRelayErrors = (
  errors: ReadonlyArray<{
    fields?: ReadonlyArray<string> | null;
    message: string;
  }>,
): string =>
  errors
    .map(({ fields, message }) =>
      fields?.length ? `${fields.join(" ")} ${message}` : message,
    )
    .join(". \n");

type ManualFileDownloadRequestFormWrapperProps = {
  setErrorFeedback: (feedback: React.ReactNode) => void;
  deviceId: string;
  showAdvancedOptions: boolean;
  destinationTypeOptions: DestinationTypeOption[];
};

const ManualFileDownloadRequestFormWrapper = ({
  setErrorFeedback,
  deviceId,
  showAdvancedOptions,
  destinationTypeOptions,
}: ManualFileDownloadRequestFormWrapperProps) => {
  const intl = useIntl();
  const [isUploading, setIsUploading] = useState(false);

  const [getPresignedUrl] =
    useMutation<FilesUploadTab_createFileDownloadRequestPresignedUrl_Mutation>(
      DEVICE_GET_PRESIGNED_URL_MUTATION,
    );

  const [createFileDownloadRequest] =
    useMutation<FilesUploadTab_createManualFileDownloadRequest_Mutation>(
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

  const handleFileUpload = useCallback(
    async (values: FileDownloadRequestFormValues) => {
      setErrorFeedback(null);
      setIsUploading(true);

      try {
        const {
          files,
          archiveName,
          destinationType,
          destination,
          ttlSeconds,
          progressTracked,
          fileMode,
          userId,
          groupId,
        } = values;

        let uploadBlob: Blob;
        let fileName: string;
        let uncompressedSize: number;
        let compression: string | null = null;

        // Files from folder selection have webkitRelativePath set.
        // These need archiving even if there's only one file, to preserve
        // the directory structure.
        const hasRelativePaths = files.some((f) => f.webkitRelativePath);
        const needsArchive = files.length > 1 || hasRelativePaths;

        if (needsArchive) {
          // Multiple files or folder contents: create tar.gz archive
          uploadBlob = await createTarGzArchive(files);
          const baseName = archiveName?.trim() || "files-archive";
          fileName = baseName.endsWith(".tar.gz")
            ? baseName
            : `${baseName}.tar.gz`;
          uncompressedSize = files.reduce((sum, f) => sum + f.size, 0);
          compression = "tar.gz";
        } else {
          uploadBlob = files[0];
          fileName = files[0].name;
          uncompressedSize = files[0].size;
        }

        if (files.length === 1 && /\.(tar\.gz|tgz)$/i.test(files[0].name)) {
          compression = "tar.gz";
        }

        const archiveData = new Uint8Array(await uploadBlob.arrayBuffer());
        const fileDownloadRequestId = uuidv7();
        const digest = await computeDigest(archiveData);

        // Get presigned URL from the backend
        const presignedUrls = await new Promise<{
          get_url: string;
          put_url: string;
        }>((resolve, reject) => {
          getPresignedUrl({
            variables: {
              input: {
                fileDownloadRequestId,
                filename: fileName,
              },
            },
            onCompleted(responseData, errors) {
              if (errors && errors.length > 0) {
                reject(new Error(formatRelayErrors(errors)));
                return;
              }
              try {
                const raw = responseData.createFileDownloadRequestPresignedUrl;
                const parsed = typeof raw === "string" ? JSON.parse(raw) : raw;
                if (!parsed?.put_url || !parsed?.get_url) {
                  reject(
                    new Error(
                      intl.formatMessage({
                        id: "components.DeviceTabs.FilesUploadTab.error.presignedUrlMissingFields",
                        defaultMessage:
                          "Presigned URL response is missing put_url or get_url.",
                      }),
                    ),
                  );
                  return;
                }
                resolve(parsed);
              } catch {
                reject(
                  new Error(
                    intl.formatMessage({
                      id: "components.DeviceTabs.FilesUploadTab.error.presignedUrlParseFailed",
                      defaultMessage:
                        "Failed to parse the presigned URL response.",
                    }),
                  ),
                );
              }
            },
            onError(error) {
              reject(error);
            },
          });
        });

        // Upload the file to the presigned PUT URL
        const uploadResponse = await fetch(presignedUrls.put_url, {
          method: "PUT",
          headers: { "x-ms-blob-type": "BlockBlob" },
          body: uploadBlob,
        });

        if (!uploadResponse.ok) {
          const responseBody = await uploadResponse.text().catch(() => "");
          throw new Error(
            intl.formatMessage(
              {
                id: "components.DeviceTabs.FilesUploadTab.error.uploadFailed",
                defaultMessage:
                  "File upload failed with status {status}: {statusText}{body}.",
              },
              {
                status: uploadResponse.status,
                statusText: uploadResponse.statusText,
                body: responseBody ? ` - ${responseBody}` : "",
              },
            ),
          );
        }

        // Create the file download request with all metadata
        await new Promise<void>((resolve, reject) => {
          createFileDownloadRequest({
            variables: {
              input: {
                deviceId,
                fileDownloadRequestId,
                url: presignedUrls.get_url,
                fileName,
                uncompressedFileSizeBytes: uncompressedSize,
                digest,
                compression,
                fileMode,
                userId,
                groupId,
                destinationType,
                destination,
                progressTracked,
                ttlSeconds,
              },
            },
            onCompleted(_responseData, errors) {
              if (errors && errors.length > 0) {
                reject(new Error(formatRelayErrors(errors)));
                return;
              }
              resolve();
            },
            updater(store, data) {
              const newRequestId =
                data?.createManualFileDownloadRequest?.result?.id;
              if (!newRequestId) return;
              const newRequest = store.get(newRequestId);
              const storedDevice = store.get(deviceId);
              if (!storedDevice || !newRequest) return;
              const connection = ConnectionHandler.getConnection(
                storedDevice,
                "FilesUploadTab_fileDownloadRequests",
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
                "FileDownloadRequestEdge",
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
                id: "components.DeviceTabs.FilesUploadTab.error.unknownError",
                defaultMessage: "An unknown error occurred.",
              });
        setErrorFeedback(message);
      } finally {
        setIsUploading(false);
      }
    },
    [
      deviceId,
      getPresignedUrl,
      createFileDownloadRequest,
      intl,
      setErrorFeedback,
    ],
  );

  return (
    <ManualFileDownloadRequestForm
      isLoading={isUploading}
      onFileSubmit={handleFileUpload}
      showAdvancedOptions={showAdvancedOptions}
      destinationTypeOptions={destinationTypeOptions}
    />
  );
};

type ManualFileDownloadRequestFromRepositoryFormWrapperProps = {
  setErrorFeedback: (feedback: React.ReactNode) => void;
  repositoriesQueryRef: PreloadedQuery<FilesUploadTab_getRepositories_Query>;
  deviceId: string;
  showAdvancedOptions: boolean;
  destinationTypeOptions: DestinationTypeOption[];
};

const ManualFileDownloadRequestFromRepositoryFormWrapper = ({
  setErrorFeedback,
  repositoriesQueryRef,
  deviceId,
  showAdvancedOptions,
  destinationTypeOptions,
}: ManualFileDownloadRequestFromRepositoryFormWrapperProps) => {
  const intl = useIntl();
  const [isUploading, setIsUploading] = useState(false);

  const repositoriesData = usePreloadedQuery(
    GET_REPOSITORIES_QUERY,
    repositoriesQueryRef,
  );

  const [createFileDownloadRequest] =
    useMutation<FilesUploadTab_createManagedFileDownloadRequest_Mutation>(
      DEVICE_CREATE_MANAGED_FILE_DOWNLOAD_REQUEST_MUTATION,
    );

  const handleFileUpload = useCallback(
    async (values: ManualFileDownloadRequestFromRepositoryData) => {
      setErrorFeedback(null);
      setIsUploading(true);

      try {
        const {
          file,
          destinationType,
          destination,
          ttlSeconds,
          progressTracked,
          fileMode,
          userId,
          groupId,
        } = values;

        let compression: string | null = null;

        if (/\.(tar\.gz|tgz)$/i.test(file.name)) {
          compression = "tar.gz";
        }

        const fileDownloadRequestId = uuidv7();

        // Create the file download request with all metadata
        await new Promise<void>((resolve, reject) => {
          createFileDownloadRequest({
            variables: {
              input: {
                deviceId,
                fileDownloadRequestId,
                fileId: file.id,
                compression,
                fileMode,
                userId,
                groupId,
                destinationType,
                destination,
                progressTracked,
                ttlSeconds,
              },
            },
            onCompleted(_responseData, errors) {
              if (errors && errors.length > 0) {
                reject(new Error(formatRelayErrors(errors)));
                return;
              }
              resolve();
            },
            updater(store, data) {
              const newRequestId =
                data?.createManagedFileDownloadRequest?.result?.id;
              if (!newRequestId) return;
              const newRequest = store.get(newRequestId);
              const storedDevice = store.get(deviceId);
              if (!storedDevice || !newRequest) return;
              const connection = ConnectionHandler.getConnection(
                storedDevice,
                "FilesUploadTab_fileDownloadRequests",
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
                "FileDownloadRequestEdge",
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
                id: "components.DeviceTabs.FilesUploadTab.error.unknownError",
                defaultMessage: "An unknown error occurred.",
              });
        setErrorFeedback(message);
      } finally {
        setIsUploading(false);
      }
    },
    [deviceId, createFileDownloadRequest, intl, setErrorFeedback],
  );

  return (
    <ManualFileDownloadRequestFromRepositoryForm
      repositoriesData={repositoriesData}
      isLoading={isUploading}
      onFileSubmit={handleFileUpload}
      showAdvancedOptions={showAdvancedOptions}
      destinationTypeOptions={destinationTypeOptions}
    />
  );
};

type FilesUploadTabProps = {
  deviceRef: FilesUploadTab_fileDownloadRequests$key;
  embedded?: boolean;
  embeddedMode?: "file" | "repository";
};

const FilesUploadTab = ({
  deviceRef,
  embedded = false,
  embeddedMode,
}: FilesUploadTabProps) => {
  const intl = useIntl();
  const { deviceId = "" } = useParams();

  const [updateMode, setUpdateMode] = useState<"repository" | "file">("file");
  const effectiveUpdateMode = embeddedMode ?? updateMode;

  const [errorFeedback, setErrorFeedback] = useState<React.ReactNode>(null);

  const { data } = usePaginationFragment<
    FilesUploadTab_PaginationQuery,
    FilesUploadTab_fileDownloadRequests$key
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
    () => data.fileDownloadRequests?.edges?.map((edge) => edge.node) ?? [],
    [data.fileDownloadRequests],
  );

  const [getRepositoriesQuery, getRepositories] =
    useQueryLoader<FilesUploadTab_getRepositories_Query>(
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

  const { capabilities } = data;

  const hasStorage =
    capabilities.includes("POSIX_FILE_TRANSFER_STORAGE") ||
    capabilities.includes("WINDOWS_FILE_TRANSFER_STORAGE");

  const hasStream =
    capabilities.includes("POSIX_FILE_TRANSFER_STREAM") ||
    capabilities.includes("WINDOWS_FILE_TRANSFER_STREAM");

  const showAdvancedOptions =
    capabilities.includes("POSIX_FILE_TRANSFER_STORAGE") ||
    capabilities.includes("POSIX_FILE_TRANSFER_STREAM");

  const destinationTypeOptions = useMemo<DestinationTypeOption[]>(() => {
    const options: DestinationTypeOption[] = [];

    if (hasStorage) {
      options.push({ value: "STORAGE", label: "Storage" });
    }

    if (hasStream) {
      options.push(
        { value: "STREAMING", label: "Streaming" },
        { value: "FILESYSTEM", label: "File System" },
      );
    }

    return options;
  }, [hasStorage, hasStream]);

  if (!hasStorage && !hasStream) {
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
                      id="components.DeviceTabs.FilesUploadTab.modeFile"
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
                      id="components.DeviceTabs.FilesUploadTab.modeRepository"
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
                showAdvancedOptions={showAdvancedOptions}
                destinationTypeOptions={destinationTypeOptions}
              />
            ) : (
              getRepositoriesQuery && (
                <ManualFileDownloadRequestFromRepositoryFormWrapper
                  repositoriesQueryRef={getRepositoriesQuery}
                  setErrorFeedback={setErrorFeedback}
                  deviceId={deviceId}
                  showAdvancedOptions={showAdvancedOptions}
                  destinationTypeOptions={destinationTypeOptions}
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
            id="components.DeviceTabs.FilesUploadTab.requestHistory"
            defaultMessage="Request History"
          />
        </h5>

        <FileDownloadRequestsTable requests={fileDownloadRequests} />
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
        id: "components.DeviceTabs.FilesUploadTab",
        defaultMessage: "Files Upload",
      })}
    >
      <div className="mt-3">
        <h5>
          <FormattedMessage
            id="components.DeviceTabs.FilesUploadTab.uploadLocation"
            defaultMessage="Upload Location"
          />
        </h5>
        {content}
      </div>
    </Tab>
  );
};

export type { DestinationTypeOption };

export default FilesUploadTab;
