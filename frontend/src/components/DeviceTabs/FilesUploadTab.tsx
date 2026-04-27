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
import { defineMessages, FormattedMessage, useIntl } from "react-intl";
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

import type { FilesUploadTab_PaginationQuery } from "@/api/__generated__/FilesUploadTab_PaginationQuery.graphql";
import type { FilesUploadTab_createManagedFileDownloadRequest_Mutation } from "@/api/__generated__/FilesUploadTab_createManagedFileDownloadRequest_Mutation.graphql";
import type {
  CreateManualFileDownloadRequestInput,
  FilesUploadTab_createManualFileDownloadRequest_Mutation,
  FilesUploadTab_createManualFileDownloadRequest_Mutation$data,
} from "@/api/__generated__/FilesUploadTab_createManualFileDownloadRequest_Mutation.graphql";
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
import { createTarArchive } from "@/lib/files";
import { PayloadError } from "relay-runtime";

// We use graphql fields below in columns configuration
/* eslint-disable relay/unused-fields */
const DEVICE_FILE_DOWNLOAD_REQUESTS_FRAGMENT = graphql`
  fragment FilesUploadTab_fileDownloadRequests on Device
  @refetchable(queryName: "FilesUploadTab_PaginationQuery") {
    id
    fileTransferCapabilities {
      encodings
      unixPermissions
      targets
    }
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

type FileDownloadRequest = NonNullable<
  FilesUploadTab_createManualFileDownloadRequest_Mutation$data["createManualFileDownloadRequest"]
>["result"];

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

class APIValidationError extends Error {
  constructor(public errors: PayloadError[]) {
    super("API Validation Error");
  }
}

type DestinationTypeOption = {
  value: FileDestinationType;
  label: string;
};

const messages = defineMessages({
  archiveError: {
    id: "components.DeviceTabs.FilesUploadTab.archivationErrorFeedback",
    defaultMessage: "Could not process files locally. Please try again.",
  },
  uploadError: {
    id: "components.DeviceTabs.FilesUploadTab.uploadErrorFeedback",
    defaultMessage: "Upload failed. Please check your connection.",
  },
});

type ManualFileDownloadRequestFormWrapperProps = {
  setErrorFeedback: (feedback: React.ReactNode) => void;
  deviceId: string;
  supportedEncodings: string[];
  allowArchiveUpload: boolean;
  showAdvancedOptions: boolean;
  destinationTypeOptions: DestinationTypeOption[];
};

const ManualFileDownloadRequestFormWrapper = ({
  setErrorFeedback,
  deviceId,
  supportedEncodings,
  allowArchiveUpload,
  showAdvancedOptions,
  destinationTypeOptions,
}: ManualFileDownloadRequestFormWrapperProps) => {
  const [isUploading, setIsUploading] = useState(false);

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

  const prepareUploadFile = async (files: File[], archiveName?: string) => {
    const hasRelativePaths = files.some((f) => !!f.webkitRelativePath);
    const needsArchive = files.length > 1 || hasRelativePaths;

    if (needsArchive) {
      const tarBlob = await createTarArchive(files);
      const baseName = archiveName?.trim() || "files-archive";
      const fileName = baseName.endsWith(".tar") ? baseName : `${baseName}.tar`;
      const uncompressedSize = files.reduce((sum, f) => sum + f.size, 0);

      return {
        file: new File([tarBlob], fileName, { type: "application/x-tar" }),
        fileName,
        uncompressedSize,
      };
    }

    return {
      file: files[0],
      fileName: files[0].name,
      uncompressedSize: files[0].size,
    };
  };

  const commitDownloadRequest = useCallback(
    (input: CreateManualFileDownloadRequestInput) =>
      new Promise<FileDownloadRequest>((resolve, reject) => {
        createFileDownloadRequest({
          variables: { input },
          onCompleted: (data, errors) => {
            if (errors && errors.length > 0) {
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
              "FilesUploadTab_fileDownloadRequests",
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
          },
        });
      }),
    [createFileDownloadRequest, deviceId],
  );

  const handleFileUpload = useCallback(
    async (values: FileDownloadRequestFormValues) => {
      const { files, archiveName, ...rest } = values;
      if (!files?.length) return;

      setIsUploading(true);
      setErrorFeedback(null);

      try {
        const { file, fileName, uncompressedSize } = await prepareUploadFile(
          files,
          archiveName,
        );

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
          const message = err.errors
            .map(({ fields, message }) =>
              fields?.length ? `${fields.join(", ")}: ${message}` : message,
            )
            .join(". ");
          setErrorFeedback(message);
        } else {
          setErrorFeedback(<FormattedMessage {...messages.uploadError} />);
        }
      }
    },
    [deviceId, commitDownloadRequest, setIsUploading, setErrorFeedback],
  );
  return (
    <ManualFileDownloadRequestForm
      isLoading={isUploading}
      onFileSubmit={handleFileUpload}
      supportedEncodings={supportedEncodings}
      allowArchiveUpload={allowArchiveUpload}
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
    (values: ManualFileDownloadRequestFromRepositoryData) => {
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

      setErrorFeedback(null);
      setIsUploading(true);

      createFileDownloadRequest({
        variables: {
          input: {
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
            const message = errors
              .map(({ fields, message }) =>
                fields?.length ? `${fields.join(", ")}: ${message}` : message,
              )
              .join(". ");
            setErrorFeedback(message);
          }
        },
        onError: () => {
          setIsUploading(false);
          setErrorFeedback(
            <FormattedMessage
              id="components.DeviceTabs.FilesUploadTab.creationErrorFeedback"
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
            "FilesUploadTab_fileDownloadRequests",
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
        },
      });
    },
    [deviceId, createFileDownloadRequest, setErrorFeedback],
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

  const showAdvancedOptions = !!data.fileTransferCapabilities?.unixPermissions;

  const destinationTypeOptions = useMemo<DestinationTypeOption[]>(
    () =>
      (data.fileTransferCapabilities?.targets ?? [])
        .filter((target): target is FileDestinationType => target != null)
        .map((target) => {
          switch (target) {
            case "STORAGE":
              return {
                value: target,
                label: intl.formatMessage({
                  id: "components.DeviceTabs.FilesUploadTab.destinationType.storage",
                  defaultMessage: "Storage",
                }),
              };
            case "STREAMING":
              return {
                value: target,
                label: intl.formatMessage({
                  id: "components.DeviceTabs.FilesUploadTab.destinationType.streaming",
                  defaultMessage: "Streaming",
                }),
              };
            case "FILESYSTEM":
              return {
                value: target,
                label: intl.formatMessage({
                  id: "components.DeviceTabs.FilesUploadTab.destinationType.filesystem",
                  defaultMessage: "File System",
                }),
              };
          }
        }),
    [data.fileTransferCapabilities?.targets, intl],
  );

  const supportedEncodings = useMemo(() => {
    const uniqueEncodings = new Set<string>();

    data.fileTransferCapabilities?.encodings?.forEach((encoding) => {
      const value = encoding?.trim();

      if (value) {
        uniqueEncodings.add(value);
      }
    });

    return Array.from(uniqueEncodings);
  }, [data.fileTransferCapabilities?.encodings]);

  const allowArchiveUpload = useMemo(
    () =>
      supportedEncodings.some((encoding) => {
        const normalizedEncoding = encoding.trim().toLowerCase();
        return (
          normalizedEncoding === "tar" ||
          normalizedEncoding === "tar.gz" ||
          normalizedEncoding === "tar.lz4"
        );
      }),
    [supportedEncodings],
  );

  if (destinationTypeOptions?.length === 0) {
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
                supportedEncodings={supportedEncodings}
                allowArchiveUpload={allowArchiveUpload}
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
