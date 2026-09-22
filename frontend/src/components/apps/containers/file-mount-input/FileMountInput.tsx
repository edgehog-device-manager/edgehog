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
  useEffect,
  useImperativeHandle,
  useMemo,
  useRef,
  useState,
} from "react";
import { FormattedMessage, useIntl } from "react-intl";
import { graphql, useLazyLoadQuery, useMutation } from "react-relay/hooks";
import { Card, Nav, ToggleButton, ToggleButtonGroup } from "react-bootstrap";
import { SingleValue } from "react-select";

import type { FileBindSpecInput } from "@/api/__generated__/InstallApplicationModal_DeployRelease_Mutation.graphql";
import type {
  FileMountInput_createManagedFileDownloadRequest_Mutation,
  FileMountInput_createManagedFileDownloadRequest_Mutation$data,
} from "@/api/__generated__/FileMountInput_createManagedFileDownloadRequest_Mutation.graphql";
import type { FileMountInput_GetRepositories_Query } from "@/api/__generated__/FileMountInput_GetRepositories_Query.graphql";
import type { FileMountInput_GetRepositoryFiles_Query } from "@/api/__generated__/FileMountInput_GetRepositoryFiles_Query.graphql";

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
  mutation FileMountInput_createManagedFileDownloadRequest_Mutation(
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
  query FileMountInput_GetRepositories_Query(
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
  query FileMountInput_GetRepositoryFiles_Query($repositoryId: ID!) {
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

export type MountMode = "repository" | "device" | "upload";
export type UploadSubTab = "text" | "file";
export type TextLanguage = "json" | "yaml" | "toml" | "plaintext";

export type DeviceFileItem = {
  id: string;
  pathOnDevice?: string | null;
  deleted?: boolean | null;
  fileDownloadRequestId?: string | null;
};

export type DownloadRequestItem = {
  id: string;
  fileName?: string | null;
  destination?: string | null;
  status?: string | null;
  deviceFileId?: string | null;
  deviceFileDeleted?: boolean | null;
};

export type SelectOption = {
  value: string;
  label: string;
};

export type FileBindOption = {
  value: string;
  label: string;
  type: "deviceFile" | "downloadRequest" | "none";
  id: string;
};

export type PendingUploadData = {
  fileMountId: string;
  file: File;
  fileName: string;
  uncompressedFileSizeBytes: number;
  digest: string;
  encoding: string;
};

export type FileBindResult = {
  spec: FileBindSpecInput;
  pendingUpload?: PendingUploadData;
};

export type FileMountInputRef = {
  getFileBindSpec: () => Promise<FileBindResult | null>;
  isValid: () => boolean;
};

export type FileMountInputProps = {
  fileMountId: string;
  mountpoint: string;
  required?: boolean;
  deviceId: string;
  defaultFileId?: string | null;
  defaultFileName?: string | null;
  deviceFiles?: DeviceFileItem[];
  fileDownloadRequests?: DownloadRequestItem[];
  onChange?: (result: FileBindResult | null, isValid: boolean) => void;
  className?: string;
  disabled?: boolean;
};

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

  const data = useLazyLoadQuery<FileMountInput_GetRepositoryFiles_Query>(
    GET_REPOSITORY_FILES_QUERY,
    { repositoryId },
    { fetchPolicy: "store-and-network" },
  );

  const fileOptions: SelectOption[] = useMemo(() => {
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
      id={`repository-file-select-${repositoryId}`}
      label={intl.formatMessage({
        id: "components.apps.containers.file-mount-input.FileMountInput.selectRepositoryFile",
        defaultMessage: "Select File from Repository",
      })}
    >
      <Select
        options={fileOptions}
        value={selectedFileOption}
        onChange={(option: SingleValue<SelectOption>) => {
          onFileChange(option?.value || "");
        }}
        placeholder={intl.formatMessage({
          id: "components.apps.containers.file-mount-input.FileMountInput.selectFilePlaceholder",
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

  const data = useLazyLoadQuery<FileMountInput_GetRepositories_Query>(
    GET_REPOSITORIES_QUERY,
    { first: 100 },
    { fetchPolicy: "store-and-network" },
  );

  const repositoryOptions: SelectOption[] = useMemo(() => {
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
        id={`repository-select-${selectedRepositoryId}`}
        label={intl.formatMessage({
          id: "components.apps.containers.file-mount-input.FileMountInput.selectRepository",
          defaultMessage: "Select Repository",
        })}
      >
        <Select
          options={repositoryOptions}
          value={selectedRepositoryOption}
          onChange={(option: SingleValue<SelectOption>) => {
            onRepositoryChange(option?.value || "");
            onFileChange("");
          }}
          placeholder={intl.formatMessage({
            id: "components.apps.containers.file-mount-input.FileMountInput.selectRepositoryPlaceholder",
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

const FileMountInput = forwardRef<FileMountInputRef, FileMountInputProps>(
  (
    {
      fileMountId,
      mountpoint,
      required = false,
      deviceId,
      defaultFileId,
      defaultFileName,
      deviceFiles = [],
      fileDownloadRequests = [],
      onChange,
      className = "",
      disabled = false,
    },
    ref,
  ) => {
    const intl = useIntl();

    // ---------------------------------------------------------------------------
    // State
    // ---------------------------------------------------------------------------

    const [mode, setMode] = useState<MountMode>("device");
    const [uploadSubTab, setUploadSubTab] = useState<UploadSubTab>("text");

    const [userSelectedDeviceFile, setUserSelectedDeviceFile] = useState<
      string | null
    >(null);

    const [selectedRepositoryId, setSelectedRepositoryId] =
      useState<string>("");
    const [selectedRepositoryFileId, setSelectedRepositoryFileId] =
      useState<string>("");

    const [textValue, setTextValue] = useState<string>("");
    const [languageHint, setLanguageHint] = useState<TextLanguage>("json");
    const [uploadFiles, setUploadFiles] = useState<File[]>([]);

    const customFileName = "";

    const [isLoading, setIsLoading] = useState<boolean>(false);
    const [errorMessage, setErrorMessage] = useState<string | null>(null);

    const onChangeRef = useRef(onChange);

    useEffect(() => {
      onChangeRef.current = onChange;
    }, [onChange]);

    // ---------------------------------------------------------------------------
    // Mutation
    // ---------------------------------------------------------------------------

    const [createManagedDownloadRequest] =
      useMutation<FileMountInput_createManagedFileDownloadRequest_Mutation>(
        CREATE_MANAGED_FILE_DOWNLOAD_REQUEST_MUTATION,
      );

    // ---------------------------------------------------------------------------
    // Device file selection
    // ---------------------------------------------------------------------------

    const computedDefaultDeviceFile = useMemo(() => {
      if (!defaultFileName && !defaultFileId) {
        return null;
      }

      const matchingDeviceFile = deviceFiles.find(
        (deviceFile) =>
          deviceFile.id === defaultFileId ||
          (defaultFileName &&
            deviceFile.pathOnDevice?.endsWith(defaultFileName)),
      );

      if (matchingDeviceFile) {
        return `deviceFile:${matchingDeviceFile.id}`;
      }

      const matchingDownloadRequest = fileDownloadRequests.find(
        (downloadRequest) =>
          downloadRequest.id === defaultFileId ||
          (defaultFileName && downloadRequest.fileName === defaultFileName),
      );

      if (matchingDownloadRequest) {
        return `downloadRequest:${matchingDownloadRequest.id}`;
      }

      return null;
    }, [defaultFileId, defaultFileName, deviceFiles, fileDownloadRequests]);

    const deviceFileOptions: FileBindOption[] = useMemo(() => {
      const options: FileBindOption[] = [];

      if (!required) {
        options.push({
          value: "none",
          label: intl.formatMessage({
            id: "components.apps.containers.file-mount-input.FileMountInput.unboundOption",
            defaultMessage: "None (Unbound)",
          }),
          type: "none",
          id: "",
        });
      }

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
        const isDefault =
          deviceFile.id === defaultFileId ||
          (!!defaultFileName &&
            deviceFile.pathOnDevice?.endsWith(defaultFileName));

        options.push({
          value: `deviceFile:${deviceFile.id}`,
          label: `Device File: ${
            deviceFile.pathOnDevice || deviceFile.id
          }${isDefault ? " (Default)" : ""}`,
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

        const isDefault =
          downloadRequest.id === defaultFileId ||
          (!!defaultFileName && downloadRequest.fileName === defaultFileName);

        options.push({
          value: `downloadRequest:${downloadRequest.id}`,
          label: `Download: ${
            downloadRequest.fileName ||
            downloadRequest.destination ||
            downloadRequest.id
          } (${downloadRequest.status || "UNKNOWN"})${
            isDefault ? " (Default)" : ""
          }`,
          type: "downloadRequest",
          id: downloadRequest.id,
        });
      });

      return options;
    }, [
      defaultFileId,
      defaultFileName,
      deviceFiles,
      fileDownloadRequests,
      intl,
      required,
    ]);

    const selectedDeviceFile =
      userSelectedDeviceFile ?? computedDefaultDeviceFile ?? "none";

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

    const isValid = useCallback((): boolean => {
      if (!required) {
        return true;
      }

      if (defaultFileId || defaultFileName) {
        return true;
      }

      switch (mode) {
        case "device":
          return !!selectedDeviceFile && selectedDeviceFile !== "none";

        case "repository":
          return !!selectedRepositoryFileId;

        case "upload":
          if (uploadSubTab === "text") {
            return textValue.trim().length > 0;
          }

          return uploadFiles.length > 0;

        default:
          return false;
      }
    }, [
      defaultFileId,
      defaultFileName,
      mode,
      required,
      selectedDeviceFile,
      selectedRepositoryFileId,
      textValue,
      uploadFiles.length,
      uploadSubTab,
    ]);

    // ---------------------------------------------------------------------------
    // Download request
    // ---------------------------------------------------------------------------

    const commitManagedDownload = useCallback(
      (fileId: string) =>
        new Promise<
          NonNullable<
            FileMountInput_createManagedFileDownloadRequest_Mutation$data["createManagedFileDownloadRequest"]
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
    // File bind
    // ---------------------------------------------------------------------------

    const getFileBindSpec =
      useCallback(async (): Promise<FileBindResult | null> => {
        setErrorMessage(null);

        const hasDefault = !!defaultFileId || !!defaultFileName;

        if (mode === "device") {
          if (!selectedDeviceFile || selectedDeviceFile === "none") {
            if (required && !hasDefault) {
              setErrorMessage(
                intl.formatMessage({
                  id: "components.apps.containers.file-mount-input.FileMountInput.requiredError",
                  defaultMessage: "This file mount is required.",
                }),
              );
            }

            return null;
          }

          const [type, id] = selectedDeviceFile.split(":");

          if (type === "deviceFile") {
            return {
              spec: {
                fileMountId,
                deviceFileId: id,
              },
            };
          }

          if (type === "downloadRequest") {
            return {
              spec: {
                fileMountId,
                fileDownloadRequestId: id,
              },
            };
          }

          return null;
        }

        // Repository mode
        if (mode === "repository") {
          if (!selectedRepositoryFileId) {
            if (required && !hasDefault) {
              setErrorMessage(
                intl.formatMessage({
                  id: "components.apps.containers.file-mount-input.FileMountInput.selectRepositoryFileError",
                  defaultMessage: "Please select a repository file.",
                }),
              );
            }

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
                fileMountId,
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

          let fileNameToUse =
            customFileName || getBaseName(mountpoint) || "mounted-file";

          if (uploadSubTab === "text") {
            if (!textValue.trim()) {
              if (required && !hasDefault) {
                setErrorMessage(
                  intl.formatMessage({
                    id: "components.apps.containers.file-mount-input.FileMountInput.emptyTextError",
                    defaultMessage: "Please enter file content.",
                  }),
                );
              }

              return null;
            }

            const mime =
              languageHint === "json" ? "application/json" : "text/plain";

            fileToUpload = new File([textValue], fileNameToUse, {
              type: mime,
            });
          } else {
            if (!uploadFiles.length) {
              if (required && !hasDefault) {
                setErrorMessage(
                  intl.formatMessage({
                    id: "components.apps.containers.file-mount-input.FileMountInput.selectFileError",
                    defaultMessage: "Please select a file to upload.",
                  }),
                );
              }

              return null;
            }

            fileToUpload = uploadFiles[0];

            if (!customFileName) {
              fileNameToUse = fileToUpload.name;
            }
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
              spec: {
                fileMountId,
              },
              pendingUpload: {
                fileMountId,
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
        customFileName,
        defaultFileId,
        defaultFileName,
        fileMountId,
        intl,
        languageHint,
        mode,
        mountpoint,
        required,
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
        getFileBindSpec,
        isValid,
      }),
      [getFileBindSpec, isValid],
    );

    // ---------------------------------------------------------------------------
    // Change callback
    // ---------------------------------------------------------------------------

    useEffect(() => {
      const handleChange = onChangeRef.current;

      if (!handleChange) {
        return;
      }

      const valid = isValid();

      if (mode === "device") {
        if (!selectedDeviceFile || selectedDeviceFile === "none") {
          handleChange(null, valid);
          return;
        }

        const [type, id] = selectedDeviceFile.split(":");

        if (type === "deviceFile") {
          handleChange(
            {
              spec: {
                fileMountId,
                deviceFileId: id,
              },
            },
            valid,
          );
          return;
        }

        if (type === "downloadRequest") {
          handleChange(
            {
              spec: {
                fileMountId,
                fileDownloadRequestId: id,
              },
            },
            valid,
          );
          return;
        }

        handleChange(null, valid);
        return;
      }

      if (mode === "repository") {
        if (selectedRepositoryFileId) {
          handleChange(
            {
              spec: {
                fileMountId,
              },
            },
            valid,
          );
        } else {
          handleChange(null, valid);
        }

        return;
      }

      if (mode === "upload") {
        if (valid) {
          handleChange(
            {
              spec: {
                fileMountId,
              },
            },
            valid,
          );
        } else {
          handleChange(null, valid);
        }

        return;
      }

      handleChange(null, valid);
    }, [
      fileMountId,
      isValid,
      mode,
      selectedDeviceFile,
      selectedRepositoryFileId,
    ]);

    // ---------------------------------------------------------------------------
    // Upload options
    // ---------------------------------------------------------------------------

    const languageOptions: SelectOption[] = [
      { value: "json", label: "JSON" },
      { value: "yaml", label: "YAML" },
      { value: "toml", label: "TOML" },
      { value: "plaintext", label: "Plain Text" },
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
            <strong>{mountpoint}</strong>{" "}
            {required ? (
              <span className="badge bg-danger ms-2">
                <FormattedMessage
                  id="components.apps.containers.file-mount-input.FileMountInput.requiredBadge"
                  defaultMessage="Required"
                />
              </span>
            ) : (
              <span className="badge bg-secondary ms-2">
                <FormattedMessage
                  id="components.apps.containers.file-mount-input.FileMountInput.optionalBadge"
                  defaultMessage="Optional"
                />
              </span>
            )}
            {defaultFileName && (
              <span className="badge bg-dark-subtle text-dark ms-2">
                <FormattedMessage
                  id="components.apps.containers.file-mount-input.FileMountInput.defaultFileBadge"
                  defaultMessage="Default: {name}"
                  values={{ name: defaultFileName }}
                />
              </span>
            )}
          </div>

          <ToggleButtonGroup
            type="radio"
            name={`mount-mode-${fileMountId}`}
            value={mode}
            onChange={(value) => {
              setMode(value);
              setErrorMessage(null);
            }}
            size="sm"
          >
            <ToggleButton
              id={`mode-device-${fileMountId}`}
              value="device"
              variant="outline-primary"
              disabled={disabled || isLoading}
            >
              <FormattedMessage
                id="components.apps.containers.file-mount-input.FileMountInput.deviceMode"
                defaultMessage="Device File"
              />
            </ToggleButton>

            <ToggleButton
              id={`mode-repository-${fileMountId}`}
              value="repository"
              variant="outline-primary"
              disabled={disabled || isLoading}
            >
              <FormattedMessage
                id="components.apps.containers.file-mount-input.FileMountInput.repositoryMode"
                defaultMessage="Repository File"
              />
            </ToggleButton>

            <ToggleButton
              id={`mode-upload-${fileMountId}`}
              value="upload"
              variant="outline-primary"
              disabled={disabled || isLoading}
            >
              <FormattedMessage
                id="components.apps.containers.file-mount-input.FileMountInput.uploadMode"
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
                id="components.apps.containers.file-mount-input.FileMountInput.processing"
                defaultMessage="Processing..."
              />
            </div>
          ) : (
            <>
              {mode === "device" && (
                <FormRow
                  id={`device-file-select-${fileMountId}`}
                  label={intl.formatMessage({
                    id: "components.apps.containers.file-mount-input.FileMountInput.selectDeviceFileLabel",
                    defaultMessage: "Select file from device",
                  })}
                >
                  <Select
                    options={deviceFileOptions}
                    value={selectedDeviceOption}
                    isDisabled={disabled}
                    menuPlacement="auto"
                    onChange={(option: SingleValue<FileBindOption>) => {
                      setUserSelectedDeviceFile(option?.value || "none");
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
                        id="components.apps.containers.file-mount-input.FileMountInput.loadingRepositories"
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
                          id="components.apps.containers.file-mount-input.FileMountInput.textEditorSubTab"
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
                          id="components.apps.containers.file-mount-input.FileMountInput.filePickerSubTab"
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
                            id="components.apps.containers.file-mount-input.FileMountInput.languageHintLabel"
                            defaultMessage="Language Format:"
                          />
                        </label>

                        <div style={{ minWidth: "160px" }}>
                          <Select
                            options={languageOptions}
                            value={selectedLanguageOption}
                            onChange={(option: SingleValue<SelectOption>) => {
                              if (option) {
                                setLanguageHint(option.value as TextLanguage);
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

export default FileMountInput;
