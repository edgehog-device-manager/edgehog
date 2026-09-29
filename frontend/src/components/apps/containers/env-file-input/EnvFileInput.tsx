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
  forwardRef,
  useCallback,
  useImperativeHandle,
  useMemo,
  useState,
} from "react";
import { FormattedMessage, useIntl } from "react-intl";
import { graphql, useLazyLoadQuery, useMutation } from "react-relay/hooks";
import { Card, Nav, ToggleButton, ToggleButtonGroup } from "react-bootstrap";
import { SingleValue } from "react-select";

import type { EnvFileSpecInput } from "@/api/__generated__/InstallApplicationModal_DeployRelease_Mutation.graphql";
import type {
  EnvFileInput_createManagedFileDownloadRequest_Mutation,
  EnvFileInput_createManagedFileDownloadRequest_Mutation$data,
} from "@/api/__generated__/EnvFileInput_createManagedFileDownloadRequest_Mutation.graphql";
import type { EnvFileInput_GetRepositories_Query } from "@/api/__generated__/EnvFileInput_GetRepositories_Query.graphql";
import type { EnvFileInput_GetRepositoryFiles_Query } from "@/api/__generated__/EnvFileInput_GetRepositoryFiles_Query.graphql";

import Alert from "@/components/ui/alert/Alert";
import FileDropzone from "@/components/files/file-download/file-dropzone/FileDropzone";
import { FormRow } from "@/components/ui/form-row/FormRow";
import MonacoEditor from "@/components/ui/monaco-editor/MonacoEditor";
import Select from "@/components/ui/select/Select";
import Spinner from "@/components/ui/spinner/Spinner";
import Stack from "@/components/ui/stack/Stack";
import {
  calculateFileDigest,
  formatFileSize,
  getBaseName,
  prepareUploadFile,
} from "@/lib/files";

const CREATE_MANAGED_FILE_DOWNLOAD_REQUEST_MUTATION = graphql`
  mutation EnvFileInput_createManagedFileDownloadRequest_Mutation(
    $input: CreateManagedFileDownloadRequestInput!
  ) {
    createManagedFileDownloadRequest(input: $input) {
      result {
        id
        fileName
        status
        destinationType
        destination
      }
      errors {
        message
      }
    }
  }
`;

const GET_REPOSITORIES_QUERY = graphql`
  query EnvFileInput_GetRepositories_Query(
    $first: Int
    $after: String
    $filter: RepositoryFilterInput = {}
  ) {
    repositories(first: $first, after: $after, filter: $filter) {
      edges {
        node {
          id
          name
        }
      }
    }
  }
`;

const GET_REPOSITORY_FILES_QUERY = graphql`
  query EnvFileInput_GetRepositoryFiles_Query($repositoryId: ID!) {
    repository(id: $repositoryId) {
      id
      files(first: 250) {
        edges {
          node {
            id
            name
          }
        }
      }
    }
  }
`;

export type EnvFileMode = "device" | "repository" | "upload";
export type EnvFileUploadSubTab = "text" | "file";
export type EnvFileTextLanguage = "plaintext" | "yaml" | "toml" | "json";

export type EnvFileDeviceFileItem = {
  id: string;
  pathOnDevice?: string | null;
  deleted?: boolean | null;
  fileDownloadRequestId?: string | null;
};

export type EnvFileDownloadRequestItem = {
  id: string;
  fileName?: string | null;
  destination?: string | null;
  status?: string | null;
  deviceFileId?: string | null;
  deviceFileDeleted?: boolean | null;
};

export type EnvFileSelectOption = {
  value: string;
  label: string;
};

export type EnvFileOption = {
  value: string;
  label: string;
  type: "deviceFile" | "downloadRequest" | "none";
  id: string;
};

export type EnvFilePendingUpload = {
  containerId: string;
  file: File;
  fileName: string;
  uncompressedFileSizeBytes: number;
  digest: string;
  encoding: string;
};

export type EnvFileResult = {
  spec: EnvFileSpecInput;
  pendingUpload?: EnvFilePendingUpload;
};

export type EnvFileInputRef = {
  getEnvFileSpec: () => Promise<EnvFileResult | null>;
  isValid: () => boolean;
};

export type EnvFileInputProps = {
  containerId: string;
  deviceId: string;
  deviceFiles?: EnvFileDeviceFileItem[];
  fileDownloadRequests?: EnvFileDownloadRequestItem[];
  className?: string;
  disabled?: boolean;
};

// Default file name used when the env file content is authored in the text
// editor, following the dotenv convention.
const DEFAULT_ENV_FILE_NAME = ".env";

const RepositoryFilesSelector = ({
  repositoryId,
  selectedRepositoryFileId,
  onFileChange,
}: {
  repositoryId: string;
  selectedRepositoryFileId: string;
  onFileChange: (fileId: string) => void;
}) => {
  const intl = useIntl();

  const data = useLazyLoadQuery<EnvFileInput_GetRepositoryFiles_Query>(
    GET_REPOSITORY_FILES_QUERY,
    { repositoryId },
    { fetchPolicy: "store-and-network" },
  );

  const fileOptions: EnvFileSelectOption[] = useMemo(() => {
    return (
      data.repository?.files?.edges
        ?.map((edge) => edge?.node)
        .filter((node): node is NonNullable<typeof node> => !!node)
        .map((file) => ({
          value: file.id,
          label: file.name,
        })) ?? []
    );
  }, [data.repository?.files?.edges]);

  const selectedFileOption = useMemo(
    () =>
      fileOptions.find((option) => option.value === selectedRepositoryFileId) ||
      null,
    [fileOptions, selectedRepositoryFileId],
  );

  return (
    <FormRow
      id={`env-file-repository-file-select-${repositoryId}`}
      label={intl.formatMessage({
        id: "components.apps.containers.env-file-input.EnvFileInput.selectRepositoryFile",
        defaultMessage: "Select File from Repository",
      })}
    >
      <Select
        options={fileOptions}
        value={selectedFileOption}
        onChange={(option: SingleValue<EnvFileSelectOption>) => {
          onFileChange(option?.value || "");
        }}
        placeholder={intl.formatMessage({
          id: "components.apps.containers.env-file-input.EnvFileInput.selectFilePlaceholder",
          defaultMessage: "Choose a file...",
        })}
      />
    </FormRow>
  );
};

const RepositorySelector = ({
  selectedRepositoryId,
  selectedRepositoryFileId,
  onRepositoryChange,
  onFileChange,
}: {
  selectedRepositoryId: string;
  selectedRepositoryFileId: string;
  onRepositoryChange: (repoId: string) => void;
  onFileChange: (fileId: string) => void;
}) => {
  const intl = useIntl();

  const data = useLazyLoadQuery<EnvFileInput_GetRepositories_Query>(
    GET_REPOSITORIES_QUERY,
    { first: 100 },
    { fetchPolicy: "store-and-network" },
  );

  const repositoryOptions: EnvFileSelectOption[] = useMemo(() => {
    return (
      data.repositories?.edges
        ?.map((edge) => edge?.node)
        .filter((node): node is NonNullable<typeof node> => !!node)
        .map((repository) => ({
          value: repository.id,
          label: repository.name,
        })) ?? []
    );
  }, [data.repositories?.edges]);

  const selectedRepositoryOption = useMemo(
    () =>
      repositoryOptions.find(
        (option) => option.value === selectedRepositoryId,
      ) || null,
    [repositoryOptions, selectedRepositoryId],
  );

  return (
    <Stack gap={2}>
      <FormRow
        id={`env-file-repository-select-${selectedRepositoryId}`}
        label={intl.formatMessage({
          id: "components.apps.containers.env-file-input.EnvFileInput.selectRepository",
          defaultMessage: "Select Repository",
        })}
      >
        <Select
          options={repositoryOptions}
          value={selectedRepositoryOption}
          onChange={(option: SingleValue<EnvFileSelectOption>) => {
            onRepositoryChange(option?.value || "");
            onFileChange("");
          }}
          placeholder={intl.formatMessage({
            id: "components.apps.containers.env-file-input.EnvFileInput.selectRepositoryPlaceholder",
            defaultMessage: "Choose a repository...",
          })}
        />
      </FormRow>

      {selectedRepositoryId && (
        <RepositoryFilesSelector
          repositoryId={selectedRepositoryId}
          selectedRepositoryFileId={selectedRepositoryFileId}
          onFileChange={onFileChange}
        />
      )}
    </Stack>
  );
};

// Single optional env file picker for one container, mirroring
// FileMountInput sources (device file / repository file / upload).
// The spec is pulled imperatively by the parent at deploy time, so no
// onChange reporting is needed: an unconfigured input simply yields null.
const EnvFileInput = forwardRef<EnvFileInputRef, EnvFileInputProps>(
  (
    {
      containerId,
      deviceId,
      deviceFiles = [],
      fileDownloadRequests = [],
      className = "",
      disabled = false,
    },
    ref,
  ) => {
    const intl = useIntl();

    // ---------------------------------------------------------------------------
    // State
    // ---------------------------------------------------------------------------

    const [mode, setMode] = useState<EnvFileMode>("device");
    const [uploadSubTab, setUploadSubTab] =
      useState<EnvFileUploadSubTab>("text");

    const [selectedDeviceFile, setSelectedDeviceFile] =
      useState<string>("none");

    const [selectedRepositoryId, setSelectedRepositoryId] =
      useState<string>("");
    const [selectedRepositoryFileId, setSelectedRepositoryFileId] =
      useState<string>("");

    const [textValue, setTextValue] = useState<string>("");
    const [languageHint, setLanguageHint] =
      useState<EnvFileTextLanguage>("plaintext");
    const [uploadFiles, setUploadFiles] = useState<File[]>([]);

    const [isLoading, setIsLoading] = useState<boolean>(false);
    const [errorMessage, setErrorMessage] = useState<string | null>(null);

    // ---------------------------------------------------------------------------
    // Mutation
    // ---------------------------------------------------------------------------

    const [createManagedDownloadRequest] =
      useMutation<EnvFileInput_createManagedFileDownloadRequest_Mutation>(
        CREATE_MANAGED_FILE_DOWNLOAD_REQUEST_MUTATION,
      );

    // ---------------------------------------------------------------------------
    // Device file selection
    // ---------------------------------------------------------------------------

    const deviceFileOptions: EnvFileOption[] = useMemo(() => {
      const options: EnvFileOption[] = [
        {
          value: "none",
          label: intl.formatMessage({
            id: "components.apps.containers.env-file-input.EnvFileInput.unboundOption",
            defaultMessage: "None (no env file)",
          }),
          type: "none",
          id: "",
        },
      ];

      const activeDeviceFiles = deviceFiles.filter(
        (deviceFile) => deviceFile.deleted !== true,
      );

      const activeDeviceFileIds = new Set(
        activeDeviceFiles.map((deviceFile) => deviceFile.id),
      );

      const downloadRequestsLinkedToDeviceFiles = new Set(
        activeDeviceFiles
          .map((deviceFile) => deviceFile.fileDownloadRequestId)
          .filter((id): id is string => !!id),
      );

      const activeFileNames = new Set(
        activeDeviceFiles
          .map((deviceFile) => getBaseName(deviceFile.pathOnDevice || ""))
          .filter(Boolean),
      );

      activeDeviceFiles.forEach((deviceFile) => {
        options.push({
          value: `deviceFile:${deviceFile.id}`,
          label: `Device File: ${deviceFile.pathOnDevice || deviceFile.id}`,
          type: "deviceFile",
          id: deviceFile.id,
        });
      });

      fileDownloadRequests.forEach((downloadRequest) => {
        const isFailed =
          downloadRequest.status === "failed" ||
          downloadRequest.deviceFileDeleted === true;

        const isLinkedToDeviceFile =
          !!downloadRequest.id &&
          downloadRequestsLinkedToDeviceFiles.has(downloadRequest.id);

        const hasActiveDeviceFile =
          !!downloadRequest.deviceFileId &&
          activeDeviceFileIds.has(downloadRequest.deviceFileId);

        const hasSameFileNameOnDevice =
          !!downloadRequest.fileName &&
          activeFileNames.has(downloadRequest.fileName);

        if (
          isFailed ||
          isLinkedToDeviceFile ||
          hasActiveDeviceFile ||
          hasSameFileNameOnDevice
        ) {
          return;
        }

        options.push({
          value: `downloadRequest:${downloadRequest.id}`,
          label: `Download: ${
            downloadRequest.fileName ||
            downloadRequest.destination ||
            downloadRequest.id
          } (${downloadRequest.status || "UNKNOWN"})`,
          type: "downloadRequest",
          id: downloadRequest.id,
        });
      });

      return options;
    }, [deviceFiles, fileDownloadRequests, intl]);

    const selectedDeviceOption = useMemo(
      () =>
        deviceFileOptions.find(
          (option) => option.value === selectedDeviceFile,
        ) || null,
      [deviceFileOptions, selectedDeviceFile],
    );

    // ---------------------------------------------------------------------------
    // Validation
    // ---------------------------------------------------------------------------

    // The env file is always optional: an unconfigured input is valid and
    // simply yields no spec.
    const isValid = useCallback((): boolean => true, []);

    // ---------------------------------------------------------------------------
    // Download request
    // ---------------------------------------------------------------------------

    const commitManagedDownload = useCallback(
      (fileId: string) =>
        new Promise<
          NonNullable<
            EnvFileInput_createManagedFileDownloadRequest_Mutation$data["createManagedFileDownloadRequest"]
          >["result"]
        >((resolve, reject) => {
          createManagedDownloadRequest({
            variables: {
              input: {
                deviceId,
                fileId,
                destinationType: "STORAGE",
              },
            },
            onCompleted: (data, errors) => {
              if (errors?.length) {
                reject(
                  new Error(errors.map((error) => error.message).join(", ")),
                );
                return;
              }

              const result = data?.createManagedFileDownloadRequest?.result;

              if (result) {
                resolve(result);
                return;
              }

              reject(
                new Error("Failed to create managed file download request."),
              );
            },
            onError: reject,
          });
        }),
      [createManagedDownloadRequest, deviceId],
    );

    // ---------------------------------------------------------------------------
    // Env file spec
    // ---------------------------------------------------------------------------

    const getEnvFileSpec =
      useCallback(async (): Promise<EnvFileResult | null> => {
        setErrorMessage(null);

        if (mode === "device") {
          if (!selectedDeviceFile || selectedDeviceFile === "none") {
            return null;
          }

          const [type, id] = selectedDeviceFile.split(":");

          if (type === "deviceFile") {
            return {
              spec: {
                deviceFileId: id,
              },
            };
          }

          if (type === "downloadRequest") {
            return {
              spec: {
                fileDownloadRequestId: id,
              },
            };
          }

          return null;
        }

        // Repository mode
        if (mode === "repository") {
          if (!selectedRepositoryFileId) {
            return null;
          }

          setIsLoading(true);

          try {
            const result = await commitManagedDownload(
              selectedRepositoryFileId,
            );

            setIsLoading(false);

            if (!result?.id) {
              throw new Error("No download request ID returned.");
            }

            return {
              spec: {
                fileDownloadRequestId: result.id,
              },
            };
          } catch (error: any) {
            setIsLoading(false);

            setErrorMessage(
              error?.message ||
                "Error creating repository file download request.",
            );

            return null;
          }
        }

        // Upload mode
        if (mode === "upload") {
          let fileToUpload: File;
          let fileNameToUse = DEFAULT_ENV_FILE_NAME;

          if (uploadSubTab === "text") {
            if (!textValue.trim()) {
              return null;
            }

            const mime =
              languageHint === "json" ? "application/json" : "text/plain";

            fileToUpload = new File([textValue], fileNameToUse, {
              type: mime,
            });
          } else {
            if (!uploadFiles.length) {
              return null;
            }

            fileToUpload = uploadFiles[0];
            fileNameToUse = fileToUpload.name;
          }

          setIsLoading(true);

          try {
            const { file, fileName, uncompressedSize } =
              await prepareUploadFile({
                files: [fileToUpload],
                customFileName: fileNameToUse,
              });

            const digest = await calculateFileDigest(file);

            setIsLoading(false);

            return {
              // Target-less spec: the backend creates the EnvFile and
              // exposes a presigned upload URL for it.
              spec: {},
              pendingUpload: {
                containerId,
                file,
                fileName,
                uncompressedFileSizeBytes: uncompressedSize,
                digest,
                encoding: "",
              },
            };
          } catch (error: any) {
            setIsLoading(false);

            setErrorMessage(error?.message || "Error preparing file upload.");

            return null;
          }
        }

        return null;
      }, [
        commitManagedDownload,
        containerId,
        languageHint,
        mode,
        selectedDeviceFile,
        selectedRepositoryFileId,
        textValue,
        uploadFiles,
        uploadSubTab,
      ]);

    // ---------------------------------------------------------------------------
    // Imperative API
    // ---------------------------------------------------------------------------

    useImperativeHandle(
      ref,
      () => ({
        getEnvFileSpec,
        isValid,
      }),
      [getEnvFileSpec, isValid],
    );

    // ---------------------------------------------------------------------------
    // Upload options
    // ---------------------------------------------------------------------------

    const languageOptions: EnvFileSelectOption[] = [
      { value: "plaintext", label: "Plain Text" },
      { value: "json", label: "JSON" },
      { value: "yaml", label: "YAML" },
      { value: "toml", label: "TOML" },
    ];

    const selectedLanguageOption =
      languageOptions.find((option) => option.value === languageHint) ||
      languageOptions[0];

    // ---------------------------------------------------------------------------
    // Render
    // ---------------------------------------------------------------------------

    return (
      <Card className={`mb-3 ${className}`}>
        <Card.Header className="d-flex align-items-center justify-content-between py-2">
          <div>
            <strong>
              <FormattedMessage
                id="components.apps.containers.env-file-input.EnvFileInput.title"
                defaultMessage="Env file"
              />
            </strong>{" "}
            <span className="badge bg-secondary ms-2">
              <FormattedMessage
                id="components.apps.containers.env-file-input.EnvFileInput.optionalBadge"
                defaultMessage="Optional"
              />
            </span>
          </div>

          <ToggleButtonGroup
            type="radio"
            name={`env-file-mode-${containerId}`}
            value={mode}
            onChange={(value) => {
              setMode(value);
              setErrorMessage(null);
            }}
            size="sm"
          >
            <ToggleButton
              id={`env-file-mode-device-${containerId}`}
              value="device"
              variant="outline-primary"
              disabled={disabled || isLoading}
            >
              <FormattedMessage
                id="components.apps.containers.env-file-input.EnvFileInput.deviceMode"
                defaultMessage="Device File"
              />
            </ToggleButton>

            <ToggleButton
              id={`env-file-mode-repository-${containerId}`}
              value="repository"
              variant="outline-primary"
              disabled={disabled || isLoading}
            >
              <FormattedMessage
                id="components.apps.containers.env-file-input.EnvFileInput.repositoryMode"
                defaultMessage="Repository File"
              />
            </ToggleButton>

            <ToggleButton
              id={`env-file-mode-upload-${containerId}`}
              value="upload"
              variant="outline-primary"
              disabled={disabled || isLoading}
            >
              <FormattedMessage
                id="components.apps.containers.env-file-input.EnvFileInput.uploadMode"
                defaultMessage="Upload"
              />
            </ToggleButton>
          </ToggleButtonGroup>
        </Card.Header>

        <Card.Body>
          {errorMessage && (
            <Alert variant="danger" className="py-2 px-3 mb-2 small">
              {errorMessage}
            </Alert>
          )}

          {isLoading ? (
            <div className="d-flex align-items-center justify-content-center p-3">
              <Spinner className="me-2" />
              <FormattedMessage
                id="components.apps.containers.env-file-input.EnvFileInput.processing"
                defaultMessage="Processing..."
              />
            </div>
          ) : (
            <>
              {mode === "device" && (
                <FormRow
                  id={`env-file-device-file-select-${containerId}`}
                  label={intl.formatMessage({
                    id: "components.apps.containers.env-file-input.EnvFileInput.selectDeviceFileLabel",
                    defaultMessage: "Select file from device",
                  })}
                >
                  <Select
                    options={deviceFileOptions}
                    value={selectedDeviceOption}
                    isDisabled={disabled}
                    menuPlacement="auto"
                    onChange={(option: SingleValue<EnvFileOption>) => {
                      setSelectedDeviceFile(option?.value || "none");
                      setErrorMessage(null);
                    }}
                  />
                </FormRow>
              )}

              {mode === "repository" && (
                <React.Suspense
                  fallback={
                    <div className="d-flex align-items-center p-2">
                      <Spinner className="me-2" />
                      <FormattedMessage
                        id="components.apps.containers.env-file-input.EnvFileInput.loadingRepositories"
                        defaultMessage="Loading repositories..."
                      />
                    </div>
                  }
                >
                  <RepositorySelector
                    selectedRepositoryId={selectedRepositoryId}
                    selectedRepositoryFileId={selectedRepositoryFileId}
                    onRepositoryChange={(id) => {
                      setSelectedRepositoryId(id);
                      setErrorMessage(null);
                    }}
                    onFileChange={(id) => {
                      setSelectedRepositoryFileId(id);
                      setErrorMessage(null);
                    }}
                  />
                </React.Suspense>
              )}

              {mode === "upload" && (
                <Stack gap={3}>
                  <Nav variant="tabs" activeKey={uploadSubTab} className="mb-2">
                    <Nav.Item>
                      <Nav.Link
                        eventKey="text"
                        onClick={() => {
                          setUploadSubTab("text");
                          setErrorMessage(null);
                        }}
                      >
                        <FormattedMessage
                          id="components.apps.containers.env-file-input.EnvFileInput.textEditorSubTab"
                          defaultMessage="Text Editor"
                        />
                      </Nav.Link>
                    </Nav.Item>

                    <Nav.Item>
                      <Nav.Link
                        eventKey="file"
                        onClick={() => {
                          setUploadSubTab("file");
                          setErrorMessage(null);
                        }}
                      >
                        <FormattedMessage
                          id="components.apps.containers.env-file-input.EnvFileInput.filePickerSubTab"
                          defaultMessage="File Picker"
                        />
                      </Nav.Link>
                    </Nav.Item>
                  </Nav>

                  {uploadSubTab === "text" && (
                    <Stack gap={2}>
                      <div className="d-flex align-items-center justify-content-between mb-1">
                        <label className="form-label mb-0">
                          <FormattedMessage
                            id="components.apps.containers.env-file-input.EnvFileInput.languageHintLabel"
                            defaultMessage="Language Format:"
                          />
                        </label>

                        <div style={{ minWidth: "160px" }}>
                          <Select
                            options={languageOptions}
                            value={selectedLanguageOption}
                            onChange={(
                              option: SingleValue<EnvFileSelectOption>,
                            ) => {
                              if (option) {
                                setLanguageHint(
                                  option.value as EnvFileTextLanguage,
                                );
                              }
                            }}
                            isSearchable={false}
                          />
                        </div>
                      </div>

                      <MonacoEditor
                        value={textValue}
                        language={
                          languageHint === "plaintext" ? "text" : languageHint
                        }
                        onChange={(value) => {
                          setTextValue(value || "");
                          setErrorMessage(null);
                        }}
                        initialLines={6}
                      />
                    </Stack>
                  )}

                  {uploadSubTab === "file" && (
                    <Stack gap={2}>
                      <FileDropzone
                        files={uploadFiles}
                        onChange={(files) => {
                          setUploadFiles(files);
                          setErrorMessage(null);
                        }}
                        allowMultiple={false}
                      />

                      {uploadFiles.length > 0 && (
                        <div className="p-2 border rounded bg-light d-flex justify-content-between align-items-center">
                          <div>
                            <strong>{uploadFiles[0].name}</strong>

                            <div className="text-muted small">
                              {formatFileSize(uploadFiles[0].size)}
                            </div>
                          </div>
                        </div>
                      )}
                    </Stack>
                  )}
                </Stack>
              )}
            </>
          )}
        </Card.Body>
      </Card>
    );
  },
);

export default EnvFileInput;
