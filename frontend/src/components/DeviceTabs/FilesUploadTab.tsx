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

import React, { useCallback, useEffect, useMemo, useState } from "react";
import { FormattedMessage, useIntl } from "react-intl";
import {
  ConnectionHandler,
  graphql,
  useMutation,
  usePaginationFragment,
} from "react-relay/hooks";
import { v7 as uuidv7 } from "uuid";

import type { FilesUploadTab_PaginationQuery } from "@/api/__generated__/FilesUploadTab_PaginationQuery.graphql";
import type { FilesUploadTab_createFileDownloadRequestPresignedUrl_Mutation } from "@/api/__generated__/FilesUploadTab_createFileDownloadRequestPresignedUrl_Mutation.graphql";
import type { FilesUploadTab_createFileDownloadRequest_Mutation } from "@/api/__generated__/FilesUploadTab_createFileDownloadRequest_Mutation.graphql";
import type { FilesUploadTab_fileDownloadRequests$key } from "@/api/__generated__/FilesUploadTab_fileDownloadRequests.graphql";

import Alert from "@/components/Alert";
import FileDownloadRequestsTable from "@/components/FileDownloadRequestsTable";
import { Tab } from "@/components/Tabs";
import type { FileDownloadRequestFormValues } from "@/forms/ManualFileDownloadRequestForm";
import ManualFileDownloadRequestForm from "@/forms/ManualFileDownloadRequestForm";
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
          statusProgress
          statusCode
          message
          destination
          progress
          ttlSeconds
          digest
          fileMode
          userId
          groupId
          uncompressedFileSizeBytes
        }
      }
    }
  }
`;

const DEVICE_GET_PRESIGNED_URL_MUTATION = graphql`
  mutation FilesUploadTab_createFileDownloadRequestPresignedUrl_Mutation(
    $input: CreateFileDownloadRequestPresignedUrlInput!
  ) {
    createFileDownloadRequestPresignedUrl(input: $input)
  }
`;

const DEVICE_CREATE_FILE_DOWNLOAD_REQUEST_MUTATION = graphql`
  mutation FilesUploadTab_createFileDownloadRequest_Mutation(
    $input: CreateFileDownloadRequestInput!
  ) {
    createFileDownloadRequest(input: $input) {
      result {
        id
        url
        fileName
        status
        statusProgress
        statusCode
        message
        destination
        progress
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

type FilesUploadTabProps = {
  deviceRef: FilesUploadTab_fileDownloadRequests$key;
};

const FilesUploadTab = ({ deviceRef }: FilesUploadTabProps) => {
  const intl = useIntl();

  const [isUploading, setIsUploading] = useState(false);
  const [errorFeedback, setErrorFeedback] = useState<React.ReactNode>(null);

  const { data } = usePaginationFragment<
    FilesUploadTab_PaginationQuery,
    FilesUploadTab_fileDownloadRequests$key
  >(DEVICE_FILE_DOWNLOAD_REQUESTS_FRAGMENT, deviceRef);

  const [getPresignedUrl] =
    useMutation<FilesUploadTab_createFileDownloadRequestPresignedUrl_Mutation>(
      DEVICE_GET_PRESIGNED_URL_MUTATION,
    );

  const [createFileDownloadRequest] =
    useMutation<FilesUploadTab_createFileDownloadRequest_Mutation>(
      DEVICE_CREATE_FILE_DOWNLOAD_REQUEST_MUTATION,
    );

  const deviceId = data.id;

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
        const { files, archiveName, destination, ttlSeconds, progress } =
          values;

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

        // Note: The browser File API does not expose Unix file permissions (fileMode),
        // userId, or groupId. These are OS-level metadata not available in web browsers.
        // We use sensible defaults: fileMode 0644 (rw-r--r--), userId -1, groupId -1.
        const fileMode = 0o644;
        const userId = -1;
        const groupId = -1;

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
                const errorMessage = errors
                  .map(({ fields, message }) =>
                    fields && fields.length
                      ? `${fields.join(" ")} ${message}`
                      : message,
                  )
                  .join(". \n");
                reject(new Error(errorMessage));
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
                destination,
                progress,
                ttlSeconds,
              },
            },
            onCompleted(_responseData, errors) {
              if (errors && errors.length > 0) {
                const errorMessage = errors
                  .map(({ fields, message }) =>
                    fields && fields.length
                      ? `${fields.join(" ")} ${message}`
                      : message,
                  )
                  .join(". \n");
                reject(new Error(errorMessage));
                return;
              }
              resolve();
            },
            updater(store, data) {
              const newRequestId = data?.createFileDownloadRequest?.result?.id;
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
    [deviceId, getPresignedUrl, createFileDownloadRequest],
  );

  const fileDownloadRequests = useMemo(
    () => data.fileDownloadRequests?.edges?.map((edge) => edge.node) ?? [],
    [data.fileDownloadRequests],
  );

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
            id="components.DeviceTabs.FilesUploadTab.manualFilesUpload"
            defaultMessage="Manual Files Upload"
          />
        </h5>
        <Alert
          show={!!errorFeedback}
          variant="danger"
          onClose={() => setErrorFeedback(null)}
          dismissible
        >
          {errorFeedback}
        </Alert>
        <ManualFileDownloadRequestForm
          isLoading={isUploading}
          onFileSubmit={handleFileUpload}
        />
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
    </Tab>
  );
};

export default FilesUploadTab;
