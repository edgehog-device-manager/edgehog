/*
 * This file is part of Edgehog.
 *
 * Copyright 2023-2026 SECO Mind Srl
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

import _ from "lodash";
import { Suspense, useCallback, useEffect, useMemo, useState } from "react";
import type { FallbackProps } from "react-error-boundary";
import { ErrorBoundary } from "react-error-boundary";
import { FormattedMessage, useIntl } from "react-intl";
import type { PreloadedQuery } from "react-relay/hooks";
import {
  graphql,
  usePaginationFragment,
  usePreloadedQuery,
  useQueryLoader,
} from "react-relay/hooks";
import Select from "react-select";

import type {
  FileSelect_FilesFragment$data,
  FileSelect_FilesFragment$key,
} from "@/api/__generated__/FileSelect_FilesFragment.graphql";
import type { FileSelect_FilesPaginationQuery } from "@/api/__generated__/FileSelect_FilesPaginationQuery.graphql";
import type { FileSelect_getRepository_Query } from "@/api/__generated__/FileSelect_getRepository_Query.graphql";

import Button from "@/components/Button";
import Spinner from "@/components/Spinner";
import Stack from "@/components/Stack";
import { RECORDS_TO_LOAD_FIRST, RECORDS_TO_LOAD_NEXT } from "@/constants";

const GET_REPOSITORY_QUERY = graphql`
  query FileSelect_getRepository_Query(
    $repositoryId: ID!
    $first: Int
    $after: String
    $filter: FileFilterInput = {}
  ) {
    repository(id: $repositoryId) {
      id
      ...FileSelect_FilesFragment
        @arguments(first: $first, after: $after, filter: $filter)
    }
  }
`;

// Fields url, digest, size are passed through to parent forms via onChange
/* eslint-disable relay/unused-fields */
const FILES_SELECT_OPTIONS_FRAGMENT = graphql`
  fragment FileSelect_FilesFragment on Repository
  @refetchable(queryName: "FileSelect_FilesPaginationQuery")
  @argumentDefinitions(
    first: { type: Int }
    after: { type: String }
    filter: { type: "FileFilterInput" }
  ) {
    files(first: $first, after: $after, filter: $filter)
      @connection(key: "FileSelect_files") {
      edges {
        node {
          id
          name
          url
          digest
          size
        }
      }
    }
  }
`;

type FileNode = NonNullable<
  NonNullable<FileSelect_FilesFragment$data["files"]>["edges"]
>[number]["node"];

type ControllerProps = {
  value: FileNode;
  invalid: boolean;
  onChange: (...event: any[]) => void;
};

type FileSelectProps = {
  filesFragmentRef: FileSelect_FilesFragment$key | null;
  controllerProps: ControllerProps;
};

const FileSelect = ({ filesFragmentRef, controllerProps }: FileSelectProps) => {
  const intl = useIntl();

  const {
    data: paginationData,
    loadNext,
    hasNext,
    isLoadingNext,
    refetch,
  } = usePaginationFragment<
    FileSelect_FilesPaginationQuery,
    FileSelect_FilesFragment$key
  >(FILES_SELECT_OPTIONS_FRAGMENT, filesFragmentRef);

  const [searchText, setSearchText] = useState<string | null>(null);

  const debounceRefetch = useMemo(
    () =>
      _.debounce((text: string) => {
        if (text === "") {
          refetch(
            {
              first: RECORDS_TO_LOAD_FIRST,
            },
            { fetchPolicy: "network-only" },
          );
        } else {
          refetch(
            {
              first: RECORDS_TO_LOAD_FIRST,
              filter: { name: { ilike: `%${text}%` } },
            },
            { fetchPolicy: "network-only" },
          );
        }
      }, 500),
    [refetch],
  );

  useEffect(() => {
    if (searchText !== null) {
      debounceRefetch(searchText);
    }
  }, [debounceRefetch, searchText]);

  const loadNextOptions = useCallback(() => {
    if (hasNext && !isLoadingNext) {
      loadNext(RECORDS_TO_LOAD_NEXT);
    }
  }, [hasNext, isLoadingNext, loadNext]);

  const files = useMemo(() => {
    return (
      paginationData?.files?.edges
        ?.map((edge) => edge?.node)
        .filter((node): node is FileNode => node != null) ?? []
    );
  }, [paginationData]);

  const getFileLabel = (file: FileNode) => file.name;
  const getFileValue = (file: FileNode) => file.id;
  const noFileOptionsMessage = (inputValue: string) =>
    inputValue
      ? intl.formatMessage(
          {
            id: "components.FileSelect.noFilesFoundMatching",
            defaultMessage: 'No files found matching "{inputValue}"',
          },
          { inputValue },
        )
      : intl.formatMessage({
          id: "components.FileSelect.noFilesAvailable",
          defaultMessage: "No files available",
        });

  return (
    <Select
      value={controllerProps.value}
      onChange={controllerProps.onChange}
      className={controllerProps.invalid ? "is-invalid" : ""}
      placeholder={intl.formatMessage({
        id: "components.FileSelect.fileOption",
        defaultMessage: "Search or select a file...",
      })}
      options={files}
      getOptionLabel={getFileLabel}
      getOptionValue={getFileValue}
      noOptionsMessage={({ inputValue }) => noFileOptionsMessage(inputValue)}
      isLoading={isLoadingNext}
      onMenuScrollToBottom={hasNext ? loadNextOptions : undefined}
      onInputChange={(text) => setSearchText(text)}
    />
  );
};

type FileSelectContentProps = {
  repositoryQuery: PreloadedQuery<FileSelect_getRepository_Query>;
  controllerProps: ControllerProps;
};

const FileSelectContent = ({
  repositoryQuery,
  controllerProps,
}: FileSelectContentProps) => {
  const { repository } = usePreloadedQuery(
    GET_REPOSITORY_QUERY,
    repositoryQuery,
  );

  return (
    <FileSelect
      filesFragmentRef={repository}
      controllerProps={controllerProps}
    />
  );
};

const ErrorFallback = ({ resetErrorBoundary }: FallbackProps) => (
  <Stack direction="horizontal">
    <span>
      <FormattedMessage
        id="components.FileSelect.ErrorFallback.message"
        defaultMessage="Failed to load files list."
      />
    </span>
    <Button variant="link" onClick={resetErrorBoundary}>
      <FormattedMessage
        id="components.FileSelect.ErrorFallback.reloadButton"
        defaultMessage="Reload"
      />
    </Button>
  </Stack>
);

type FileSelectWrapperProps = {
  selectedRepository: { id: string; name: string };
  controllerProps: ControllerProps;
};

const FileSelectWrapper = ({
  selectedRepository,
  controllerProps,
}: FileSelectWrapperProps) => {
  const [getRepositoryQuery, getRepository] =
    useQueryLoader<FileSelect_getRepository_Query>(GET_REPOSITORY_QUERY);

  const fetchRepository = useCallback(() => {
    getRepository(
      {
        repositoryId: selectedRepository?.id || "",
        first: RECORDS_TO_LOAD_FIRST,
      },
      { fetchPolicy: "network-only" },
    );
  }, [getRepository, selectedRepository]);

  useEffect(fetchRepository, [fetchRepository]);

  return (
    <ErrorBoundary onReset={fetchRepository} FallbackComponent={ErrorFallback}>
      <Suspense fallback={<Spinner />}>
        {getRepositoryQuery && (
          <FileSelectContent
            repositoryQuery={getRepositoryQuery}
            controllerProps={controllerProps}
          />
        )}
      </Suspense>
    </ErrorBoundary>
  );
};

export default FileSelectWrapper;
