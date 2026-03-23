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
import type { FileCreate_deleteFile_Mutation } from "@/api/__generated__/FileCreate_deleteFile_Mutation.graphql";
import type {
  FileCreate_getOptions_Query,
  FileCreate_getOptions_Query$data,
} from "@/api/__generated__/FileCreate_getOptions_Query.graphql";
import type { FileCreate_setFileUploaded_Mutation } from "@/api/__generated__/FileCreate_setFileUploaded_Mutation.graphql";

import Alert from "@/components/Alert";
import Center from "@/components/Center";
import Page from "@/components/Page";
import Result from "@/components/Result";
import Spinner from "@/components/Spinner";
import CreateFileForm, { FileFormOutputData } from "@/forms/CreateFile";
import { computeDigest, createTarGzArchive } from "@/lib/files";
import { Link, Route, useNavigate } from "@/Navigation";

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
        putPresignedUrl
      }
    }
  }
`;

const SET_FILE_UPLOADED_MUTATION = graphql`
  mutation FileCreate_setFileUploaded_Mutation($fileId: ID!) {
    setFileUploaded(id: $fileId) {
      result {
        id
        fileUploaded
      }
    }
  }
`;

const DELETE_FILE_MUTATION = graphql`
  mutation FileCreate_deleteFile_Mutation($fileId: ID!) {
    deleteFile(id: $fileId) {
      result {
        id
      }
    }
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

  const [createFile, isCreatingFile] =
    useMutation<FileCreate_createFile_Mutation>(CREATE_FILE_MUTATION);

  const [setFileUploaded] = useMutation<FileCreate_setFileUploaded_Mutation>(
    SET_FILE_UPLOADED_MUTATION,
  );

  const [deleteFile] =
    useMutation<FileCreate_deleteFile_Mutation>(DELETE_FILE_MUTATION);

  const commitCreateFile = useCallback(
    (input: FileCreate_createFile_Mutation["variables"]["input"]) =>
      new Promise<
        NonNullable<
          FileCreate_createFile_Mutation["response"]["createFile"]
        >["result"]
      >((resolve, reject) => {
        createFile({
          variables: { input },
          onCompleted: (data, errors) => {
            if (errors?.length) return reject(errors);

            const result = data.createFile?.result;
            if (!result) return reject(new Error("Missing file result"));

            resolve(result);
          },
          onError: reject,
        });
      }),
    [createFile],
  );

  const commitSetFileUploaded = useCallback(
    (variables: FileCreate_setFileUploaded_Mutation["variables"]) =>
      new Promise<void>((resolve, reject) => {
        setFileUploaded({
          variables,
          onCompleted: (_data, errors) => {
            if (errors?.length) return reject(errors);
            resolve();
          },
          onError: reject,
        });
      }),
    [setFileUploaded],
  );

  const commitDeleteFile = useCallback(
    (variables: FileCreate_deleteFile_Mutation["variables"]) =>
      new Promise<void>((resolve, reject) => {
        deleteFile({
          variables,
          onCompleted: (_data, errors) => {
            if (errors?.length) return reject(errors);
            resolve();
          },
          onError: reject,
        });
      }),
    [deleteFile],
  );

  const handleCreateFile = useCallback(
    async (values: FileFormOutputData) => {
      try {
        const { files, archiveName, repositoryId } = values;

        let uploadBlob: Blob;
        let fileName: string;
        let uncompressedSize: number;

        const hasRelativePaths = files.some((f) => f.webkitRelativePath);
        const needsArchive = files.length > 1 || hasRelativePaths;

        if (needsArchive) {
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

        const result = await commitCreateFile({
          repositoryId,
          name: fileName,
          size: uncompressedSize,
          digest,
        });

        if (!result) {
          throw new Error("File creation returned no result");
        }

        const fileId = result.id;

        if (!result.putPresignedUrl) {
          throw new Error("Missing upload URL");
        }

        setIsUploading(true);

        try {
          const uploadResponse = await fetch(result.putPresignedUrl, {
            method: "PUT",
            headers: {
              "x-ms-blob-type": "BlockBlob",
            },
            body: uploadBlob,
          });

          if (!uploadResponse.ok) {
            await commitDeleteFile({ fileId });

            throw new Error(
              intl.formatMessage(
                {
                  id: "pages.FileCreate.error.uploadFailed",
                  defaultMessage:
                    "File upload failed with status {status}: {statusText}.",
                },
                {
                  status: uploadResponse.status,
                  statusText: uploadResponse.statusText,
                },
              ),
            );
          }
        } finally {
          setIsUploading(false);
        }

        await commitSetFileUploaded({ fileId });

        setErrorFeedback(null);

        navigate({
          route: Route.repositoryEdit,
          params: { repositoryId },
        });
      } catch (err: unknown) {
        let message: React.ReactNode = null;

        if (Array.isArray(err) && err.every((e) => e?.message)) {
          message = err.map((e) => e.message).join(".\n");
        } else if (err instanceof Error) {
          message = err.message;
        }

        setErrorFeedback(
          message || (
            <FormattedMessage
              id="pages.FileCreate.creationErrorFeedback"
              defaultMessage="Could not create the File, please try again."
            />
          ),
        );
      }
    },
    [commitCreateFile, commitSetFileUploaded, commitDeleteFile, navigate, intl],
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
