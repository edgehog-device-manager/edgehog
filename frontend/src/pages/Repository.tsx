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

import _ from "lodash";
import { Suspense, useCallback, useEffect, useMemo, useState } from "react";
import { ErrorBoundary } from "react-error-boundary";
import { FormattedMessage } from "react-intl";
import type { PreloadedQuery } from "react-relay/hooks";
import {
  ConnectionHandler,
  graphql,
  useMutation,
  usePaginationFragment,
  usePreloadedQuery,
  useQueryLoader,
} from "react-relay/hooks";
import { useParams } from "react-router-dom";

import { Files_PaginationQuery } from "@/api/__generated__/Files_PaginationQuery.graphql";
import { Repository_FilesFragment$key } from "@/api/__generated__/Repository_FilesFragment.graphql";
import type { Repository_deleteRepository_Mutation } from "@/api/__generated__/Repository_deleteRepository_Mutation.graphql";
import type {
  Repository_getRepository_Query,
  Repository_getRepository_Query$data,
} from "@/api/__generated__/Repository_getRepository_Query.graphql";
import type { Repository_updateRepository_Mutation } from "@/api/__generated__/Repository_updateRepository_Mutation.graphql";

import { Link, Route, useNavigate } from "@/Navigation";
import Alert from "@/components/Alert";
import Button from "@/components/Button";
import Center from "@/components/Center";
import DeleteModal from "@/components/DeleteModal";
import FilesTable from "@/components/FilesTable";
import Page from "@/components/Page";
import Result from "@/components/Result";
import SearchBox from "@/components/SearchBox";
import Spinner from "@/components/Spinner";
import { RECORDS_TO_LOAD_FIRST, RECORDS_TO_LOAD_NEXT } from "@/constants";
import UpdateRepositoryForm, {
  RepositoryOutputData,
} from "@/forms/UpdateRepository";

/* eslint-disable relay/unused-fields */
const GET_REPOSITORY_QUERY = graphql`
  query Repository_getRepository_Query(
    $repositoryId: ID!
    $first: Int
    $after: String
    $filter: FileFilterInput = {}
  ) {
    repository(id: $repositoryId) {
      id
      name
      handle
      description
      ...UpdateRepository_RepositoryFragment
      ...Repository_FilesFragment
        @arguments(first: $first, after: $after, filter: $filter)
    }
  }
`;

/* eslint-disable relay/unused-fields */
const FILES_FRAGMENT = graphql`
  fragment Repository_FilesFragment on Repository
  @refetchable(queryName: "Files_PaginationQuery")
  @argumentDefinitions(
    first: { type: "Int" }
    after: { type: "String" }
    filter: { type: "FileFilterInput", defaultValue: {} }
  ) {
    id
    files(first: $first, after: $after, filter: $filter)
      @connection(key: "Repository_files") {
      edges {
        node {
          __typename
        }
      }
      ...FilesTable_FileEdgeFragment
    }
  }
`;

const UPDATE_REPOSITORY_MUTATION = graphql`
  mutation Repository_updateRepository_Mutation(
    $repositoryId: ID!
    $input: UpdateRepositoryInput!
  ) {
    updateRepository(id: $repositoryId, input: $input) {
      result {
        id
        name
        handle
        description
        ...UpdateRepository_RepositoryFragment
      }
    }
  }
`;

const DELETE_REPOSITORY_MUTATION = graphql`
  mutation Repository_deleteRepository_Mutation($repositoryId: ID!) {
    deleteRepository(id: $repositoryId) {
      result {
        id
      }
    }
  }
`;

interface FilesLayoutContainerProps {
  setErrorFeedback: (feedback: React.ReactNode) => void;
  repositoryRef: Repository_FilesFragment$key;
  searchText: string | null;
}

const FilesLayoutContainer = ({
  setErrorFeedback,
  repositoryRef,
  searchText,
}: FilesLayoutContainerProps) => {
  const { data, loadNext, hasNext, isLoadingNext, refetch } =
    usePaginationFragment<Files_PaginationQuery, Repository_FilesFragment$key>(
      FILES_FRAGMENT,
      repositoryRef,
    );

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
              filter: {
                or: [{ name: { ilike: `%${text}%` } }],
              },
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
    return () => {
      debounceRefetch.cancel();
    };
  }, [debounceRefetch, searchText]);

  const loadNextFiles = useCallback(() => {
    if (hasNext && !isLoadingNext) {
      loadNext(RECORDS_TO_LOAD_NEXT);
    }
  }, [hasNext, isLoadingNext, loadNext]);

  const filesRef = data?.files;

  if (!filesRef) {
    return null;
  }

  return (
    <FilesTable
      setErrorFeedback={setErrorFeedback}
      filesRef={filesRef}
      loading={isLoadingNext}
      onLoadMore={hasNext ? loadNextFiles : undefined}
    />
  );
};

interface RepositoryContentProps {
  repository: NonNullable<Repository_getRepository_Query$data["repository"]>;
}

const RepositoryContent = ({ repository }: RepositoryContentProps) => {
  const navigate = useNavigate();

  const [showDeleteModal, setShowDeleteModal] = useState(false);
  const [errorFeedback, setErrorFeedback] = useState<React.ReactNode>(null);
  const [searchText, setSearchText] = useState<string | null>(null);

  const repositoryId = repository.id;

  const handleShowDeleteModal = useCallback(() => {
    setShowDeleteModal(true);
  }, [setShowDeleteModal]);

  const [deleteRepository, isDeletingRepository] =
    useMutation<Repository_deleteRepository_Mutation>(
      DELETE_REPOSITORY_MUTATION,
    );

  const handleDeleteRepository = useCallback(() => {
    deleteRepository({
      variables: { repositoryId },
      onCompleted(data, errors) {
        if (!errors || errors.length === 0 || errors[0].code === "not_found") {
          return navigate({ route: Route.repositories });
        }

        const errorFeedback = errors
          .map(({ fields, message }) =>
            fields.length ? `${fields.join(" ")} ${message}` : message,
          )
          .join(". \n");
        setErrorFeedback(errorFeedback);
        setShowDeleteModal(false);
      },
      onError() {
        setErrorFeedback(
          <FormattedMessage
            id="pages.Repository.deletionErrorFeedback"
            defaultMessage="Could not delete the repository, please try again."
          />,
        );
        setShowDeleteModal(false);
      },
      updater(store, data) {
        const repositoryId = data?.deleteRepository?.result?.id;
        if (!repositoryId) {
          return;
        }

        const root = store.getRoot();

        const connection = ConnectionHandler.getConnection(
          root,
          "Repositories_repositories",
        );

        if (connection) {
          ConnectionHandler.deleteNode(connection, repositoryId);
        }

        store.delete(repositoryId);
      },
    });
  }, [deleteRepository, repositoryId, navigate]);

  const [updateRepository, isUpdatingRepository] =
    useMutation<Repository_updateRepository_Mutation>(
      UPDATE_REPOSITORY_MUTATION,
    );

  const handleUpdateRepository = useCallback(
    (repository: RepositoryOutputData) => {
      updateRepository({
        variables: { repositoryId, input: repository },
        onCompleted(data, errors) {
          if (errors) {
            const errorFeedback = errors
              .map(({ fields, message }) =>
                fields.length ? `${fields.join(" ")} ${message}` : message,
              )
              .join(". \n");
            return setErrorFeedback(errorFeedback);
          }
          setErrorFeedback(null);
        },
        onError() {
          setErrorFeedback(
            <FormattedMessage
              id="pages.Repository.creationErrorFeedback"
              defaultMessage="Could not update the repository, please try again."
            />,
          );
        },
      });
    },
    [updateRepository, repositoryId],
  );

  return (
    <Page>
      <Page.Header title={repository.name} />
      <Page.Main>
        <Alert
          show={!!errorFeedback}
          variant="danger"
          onClose={() => setErrorFeedback(null)}
          dismissible
        >
          {errorFeedback}
        </Alert>
        <div className="mb-3">
          <UpdateRepositoryForm
            repositoryRef={repository}
            onSubmit={handleUpdateRepository}
            onDelete={handleShowDeleteModal}
            isLoading={isUpdatingRepository}
          />
        </div>
        <hr className="bg-secondary border-2 border-top border-secondary" />
        <div className="d-flex justify-content-between align-items-end">
          <h3 className="m-0">
            <FormattedMessage
              id="pages.Repository.filesLabel"
              defaultMessage="Files"
            />
          </h3>
          <Button
            variant="secondary"
            as={Link}
            route={Route.filesNew}
            params={{ repositoryId }}
          >
            <FormattedMessage
              id="pages.Repository.createFileButton"
              defaultMessage="Create File"
            />
          </Button>
        </div>
        <SearchBox
          className="flex-grow-1 pt-2 pb-2"
          value={searchText || ""}
          onChange={setSearchText}
        />
        <FilesLayoutContainer
          setErrorFeedback={setErrorFeedback}
          repositoryRef={repository}
          searchText={searchText}
        />
        {showDeleteModal && (
          <DeleteModal
            confirmText={repository.handle}
            onCancel={() => setShowDeleteModal(false)}
            onConfirm={handleDeleteRepository}
            isDeleting={isDeletingRepository}
            title={
              <FormattedMessage
                id="pages.Repository.deleteModal.title"
                defaultMessage="Delete repository"
                description="Title for the confirmation modal to delete a Repository"
              />
            }
          >
            <p>
              <FormattedMessage
                id="pages.Repository.deleteModal.description"
                defaultMessage="This action cannot be undone. This will permanently delete the Repository <bold>{repository}</bold>."
                description="Description for the confirmation modal to delete a Repository"
                values={{
                  repository: repository.name,
                  bold: (chunks: React.ReactNode) => <strong>{chunks}</strong>,
                }}
              />
            </p>
          </DeleteModal>
        )}
      </Page.Main>
    </Page>
  );
};

type RepositoryWrapperProps = {
  getRepositoryQuery: PreloadedQuery<Repository_getRepository_Query>;
};

const RepositoryWrapper = ({ getRepositoryQuery }: RepositoryWrapperProps) => {
  const { repository } = usePreloadedQuery(
    GET_REPOSITORY_QUERY,
    getRepositoryQuery,
  );

  if (!repository) {
    return (
      <Result.NotFound
        title={
          <FormattedMessage
            id="pages.Repository.repositoryNotFound.title"
            defaultMessage="Repository not found."
          />
        }
      >
        <Link route={Route.repositories}>
          <FormattedMessage
            id="pages.Repository.repositoryNotFound.message"
            defaultMessage="Return to the repository list."
          />
        </Link>
      </Result.NotFound>
    );
  }

  return <RepositoryContent repository={repository} />;
};

const RepositoryPage = () => {
  const { repositoryId = "" } = useParams();

  const [getRepositoryQuery, getRepository] =
    useQueryLoader<Repository_getRepository_Query>(GET_REPOSITORY_QUERY);

  const fetchRepository = useCallback(() => {
    getRepository({ repositoryId }, { fetchPolicy: "network-only" });
  }, [getRepository, repositoryId]);

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
          <RepositoryWrapper getRepositoryQuery={getRepositoryQuery} />
        )}
      </ErrorBoundary>
    </Suspense>
  );
};

export default RepositoryPage;
