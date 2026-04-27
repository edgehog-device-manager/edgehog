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
import { FormattedMessage } from "react-intl";
import type { PreloadedQuery } from "react-relay/hooks";
import {
  graphql,
  useMutation,
  usePreloadedQuery,
  useQueryLoader,
} from "react-relay/hooks";
import { useParams } from "react-router-dom";

import type { FileCreate_createFile_Mutation } from "@/api/__generated__/FileCreate_createFile_Mutation.graphql";
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
import { createTarArchive } from "@/lib/files";
import { Link, Route, useNavigate } from "@/Navigation";
import { PayloadError } from "relay-runtime";

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

class APIValidationError extends Error {
  constructor(public errors: PayloadError[]) {
    super("API Validation Error");
  }
}

type FileCreateContentProps = {
  repository: NonNullable<FileCreate_getOptions_Query$data["repository"]>;
};

const FileCreateContent = ({ repository }: FileCreateContentProps) => {
  const navigate = useNavigate();

  const [isUploading, setIsUploading] = useState(false);
  const [errorFeedback, setErrorFeedback] = useState<React.ReactNode>(null);

  const [createFile, isCreatingFile] =
    useMutation<FileCreate_createFile_Mutation>(CREATE_FILE_MUTATION);

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

    const singleFile = files[0];
    return {
      file: singleFile,
      fileName: singleFile.name,
      uncompressedSize: singleFile.size,
    };
  };

  const commitCreateFile = useCallback(
    (input: FileCreate_createFile_Mutation["variables"]["input"]) =>
      new Promise((resolve, reject) => {
        createFile({
          variables: { input },
          onCompleted: (data, errors) => {
            if (errors && errors.length > 0) {
              return reject(new APIValidationError(errors));
            }

            const result = data?.createFile?.result;
            if (result) {
              resolve(result);
            } else {
              reject(new Error("No result returned from mutation"));
            }
          },
          onError: (err) => reject(err),
        });
      }),
    [createFile],
  );

  const handleCreateFile = useCallback(
    async (values: FileFormOutputData) => {
      const { files, archiveName, repositoryId } = values;
      if (!files?.length) return;

      setIsUploading(true);
      setErrorFeedback(null);

      try {
        const { file, fileName, uncompressedSize } = await prepareUploadFile(
          files,
          archiveName,
        );

        await commitCreateFile({
          repositoryId,
          file,
          name: fileName,
          size: uncompressedSize,
        });

        setIsUploading(false);
        navigate({
          route: Route.repositoryEdit,
          params: { repositoryId },
        });
      } catch (err) {
        setIsUploading(false);

        if (err instanceof APIValidationError) {
          const message = err.errors
            .map(({ fields, message }) =>
              fields.length ? `${fields.join(", ")}: ${message}` : message,
            )
            .join(". ");
          setErrorFeedback(message);
        } else {
          setErrorFeedback(
            <FormattedMessage
              id="pages.FileCreate.archivationErrorFeedback"
              defaultMessage="Could not process or upload selected files. {details}"
              values={{ details: err instanceof Error ? err.message : "" }}
            />,
          );
        }
      }
    },
    [navigate, commitCreateFile, setIsUploading, setErrorFeedback],
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
