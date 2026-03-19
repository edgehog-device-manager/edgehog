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

import { Suspense, useCallback, useEffect, useState } from "react";
import { ErrorBoundary } from "react-error-boundary";
import { FormattedMessage, useIntl } from "react-intl";
import type { PreloadedQuery } from "react-relay/hooks";
import {
  graphql,
  useMutation,
  usePreloadedQuery,
  useQueryLoader,
} from "react-relay/hooks";
import { useParams } from "react-router-dom";

import type { FileCreate_createFile_Mutation } from "@/api/__generated__/FileCreate_createFile_Mutation.graphql";
import type { FileCreate_createFilePresignedUrl_Mutation } from "@/api/__generated__/FileCreate_createFilePresignedUrl_Mutation.graphql";
import type {
  FileCreate_getOptions_Query,
  FileCreate_getOptions_Query$data,
} from "@/api/__generated__/FileCreate_getOptions_Query.graphql";

import Alert from "@/components/Alert";
import Center from "@/components/Center";
import Page from "@/components/Page";
import Result from "@/components/Result";
import Spinner from "@/components/Spinner";
import CreateFileForm, { FileFormOutputData } from "@/forms/CreateFile";
import { computeDigest, createTarGzArchive } from "@/lib/files";
import { Link, Route, useNavigate } from "@/Navigation";

/* eslint-disable relay/unused-fields */
const GET_REPOSITORY_QUERY = graphql`
  query FileCreate_getOptions_Query($repositoryId: ID!) {
    repository(id: $repositoryId) {
      id
      ...CreateFile_RepositoryFragment
    }
  }
`;

const CREATE_FILE_MUTATION = graphql`
  mutation FileCreate_createFile_Mutation($input: CreateFileInput!) {
    createFile(input: $input) {
      result {
        id
        name
      }
    }
  }
`;

const FILE_GET_PRESIGNED_URL_MUTATION = graphql`
  mutation FileCreate_createFilePresignedUrl_Mutation(
    $input: CreateFilePresignedUrlInput!
  ) {
    createFilePresignedUrl(input: $input)
  }
`;

type FileCreateContentProps = {
  repository: NonNullable<FileCreate_getOptions_Query$data["repository"]>;
};

const FileCreateContent = ({ repository }: FileCreateContentProps) => {
  const intl = useIntl();
  const navigate = useNavigate();

  const [isUploading, setIsUploading] = useState(false);
  const [errorFeedback, setErrorFeedback] = useState<React.ReactNode>(null);

  const [getPresignedUrl] =
    useMutation<FileCreate_createFilePresignedUrl_Mutation>(
      FILE_GET_PRESIGNED_URL_MUTATION,
    );

  const [createFile, isCreatingFile] =
    useMutation<FileCreate_createFile_Mutation>(CREATE_FILE_MUTATION);

  const handleCreateFile = useCallback(
    async (values: FileFormOutputData) => {
      setErrorFeedback(null);
      setIsUploading(true);

      try {
        const { files, archiveName, repositoryId } = values;

        let uploadBlob: Blob;
        let fileName: string;
        let uncompressedSize: number;

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
        } else {
          uploadBlob = files[0];
          fileName = files[0].name;
          uncompressedSize = files[0].size;
        }

        const archiveData = new Uint8Array(await uploadBlob.arrayBuffer());
        const digest = await computeDigest(archiveData);

        // Get presigned URL from the backend
        const presignedUrls = await new Promise<{
          get_url: string;
          put_url: string;
        }>((resolve, reject) => {
          getPresignedUrl({
            variables: {
              input: {
                repositoryId,
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
                const raw = responseData.createFilePresignedUrl;
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

        await new Promise<void>((resolve, reject) => {
          createFile({
            variables: {
              input: {
                repositoryId,
                name: fileName,
                size: uncompressedSize,
                digest,
              },
            },
            onCompleted(data, errors) {
              if (data.createFile?.result) {
                return navigate({
                  route: Route.repositoryEdit,
                  params: { repositoryId },
                });
              }

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
    [getPresignedUrl, createFile, intl, navigate],
  );

  return (
    <Page>
      <Page.Header
        title={
          <FormattedMessage
            id="pages.FileCreate.title"
            defaultMessage="Create File"
          />
        }
      />
      <Page.Main>
        <Alert
          show={!!errorFeedback}
          variant="danger"
          onClose={() => setErrorFeedback(null)}
          dismissible
        >
          {errorFeedback}
        </Alert>
        <CreateFileForm
          repositoryRef={repository}
          onSubmit={handleCreateFile}
          isLoading={isCreatingFile || isUploading}
        />
      </Page.Main>
    </Page>
  );
};

type FileCreateWrapperProps = {
  getRepositoryQuery: PreloadedQuery<FileCreate_getOptions_Query>;
};

const FileCreateWrapper = ({ getRepositoryQuery }: FileCreateWrapperProps) => {
  const { repository } = usePreloadedQuery(
    GET_REPOSITORY_QUERY,
    getRepositoryQuery,
  );

  if (!repository) {
    return (
      <Result.NotFound
        title={
          <FormattedMessage
            id="pages.FileCreate.repositoryNotFound.title"
            defaultMessage="Repository not found."
          />
        }
      >
        <Link route={Route.repositories}>
          <FormattedMessage
            id="pages.FileCreate.repositoryNotFound.message"
            defaultMessage="Return to the Repository list."
          />
        </Link>
      </Result.NotFound>
    );
  }

  return <FileCreateContent repository={repository} />;
};

const FileCreatePage = () => {
  const { repositoryId = "" } = useParams();

  const [getRepositoryQuery, getRepository] =
    useQueryLoader<FileCreate_getOptions_Query>(GET_REPOSITORY_QUERY);

  const fetchRepository = useCallback(
    () => getRepository({ repositoryId }, { fetchPolicy: "network-only" }),
    [getRepository, repositoryId],
  );

  useEffect(fetchRepository, [fetchRepository]);

  return (
    <Suspense
      fallback={
        <Center data-testid="page-loading">
          <Spinner />
        </Center>
      }
    >
      <ErrorBoundary
        FallbackComponent={(props) => (
          <Center data-testid="page-error">
            <Page.LoadingError onRetry={props.resetErrorBoundary} />
          </Center>
        )}
        onReset={fetchRepository}
      >
        {getRepositoryQuery && (
          <FileCreateWrapper getRepositoryQuery={getRepositoryQuery} />
        )}
      </ErrorBoundary>
    </Suspense>
  );
};

export default FileCreatePage;
