// This file is part of Edgehog.
//
// Copyright 2023-2026 SECO Mind Srl
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//    http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//
// SPDX-License-Identifier: Apache-2.0

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

import { BaseImageCollection_BaseImagesFragment$key } from "@/api/__generated__/BaseImageCollection_BaseImagesFragment.graphql";
import type { BaseImageCollection_deleteBaseImageCollection_Mutation } from "@/api/__generated__/BaseImageCollection_deleteBaseImageCollection_Mutation.graphql";
import type {
  BaseImageCollection_getBaseImageCollection_Query,
  BaseImageCollection_getBaseImageCollection_Query$data,
} from "@/api/__generated__/BaseImageCollection_getBaseImageCollection_Query.graphql";
import type { BaseImageCollection_updateBaseImageCollection_Mutation } from "@/api/__generated__/BaseImageCollection_updateBaseImageCollection_Mutation.graphql";
import { BaseImages_PaginationQuery } from "@/api/__generated__/BaseImages_PaginationQuery.graphql";

import { Link, Route, useNavigate } from "@/Navigation";
import Alert from "@/components/Alert";
import BaseImagesTable from "@/components/BaseImagesTable";
import Button from "@/components/Button";
import Center from "@/components/Center";
import DeleteModal from "@/components/DeleteModal";
import Page from "@/components/Page";
import Result from "@/components/Result";
import SearchBox from "@/components/SearchBox";
import Spinner from "@/components/Spinner";
import { RECORDS_TO_LOAD_FIRST, RECORDS_TO_LOAD_NEXT } from "@/constants";
import type { BaseImageCollectionChanges } from "@/forms/UpdateBaseImageCollection";
import UpdateBaseImageCollectionForm from "@/forms/UpdateBaseImageCollection";

const GET_BASE_IMAGE_COLLECTION_QUERY = graphql`
  query BaseImageCollection_getBaseImageCollection_Query(
    $baseImageCollectionId: ID!
    $first: Int
    $after: String
    $filter: BaseImageFilterInput = {}
  ) {
    baseImageCollection(id: $baseImageCollectionId) {
      id
      name
      handle
      ...UpdateBaseImageCollection_SystemModelFragment
      ...BaseImageCollection_BaseImagesFragment
        @arguments(first: $first, after: $after, filter: $filter)
    }
  }
`;

/* eslint-disable relay/unused-fields */
const BASE_IMAGES_FRAGMENT = graphql`
  fragment BaseImageCollection_BaseImagesFragment on BaseImageCollection
  @refetchable(queryName: "BaseImages_PaginationQuery")
  @argumentDefinitions(
    first: { type: "Int" }
    after: { type: "String" }
    filter: { type: "BaseImageFilterInput", defaultValue: {} }
  ) {
    id
    baseImages(first: $first, after: $after, filter: $filter)
      @connection(key: "BaseImageCollection_baseImages") {
      edges {
        node {
          __typename
        }
      }
      ...BaseImagesTable_BaseImageEdgeFragment
    }
  }
`;

const UPDATE_BASE_IMAGE_COLLECTION_MUTATION = graphql`
  mutation BaseImageCollection_updateBaseImageCollection_Mutation(
    $baseImageCollectionId: ID!
    $first: Int
    $after: String
    $input: UpdateBaseImageCollectionInput!
  ) {
    updateBaseImageCollection(id: $baseImageCollectionId, input: $input) {
      result {
        id
        name
        handle
        ...UpdateBaseImageCollection_SystemModelFragment
        ...BaseImageCollection_BaseImagesFragment
          @arguments(first: $first, after: $after, filter: {})
      }
    }
  }
`;

const DELETE_BASE_IMAGE_COLLECTION_MUTATION = graphql`
  mutation BaseImageCollection_deleteBaseImageCollection_Mutation(
    $baseImageCollectionId: ID!
  ) {
    deleteBaseImageCollection(id: $baseImageCollectionId) {
      result {
        id
      }
    }
  }
`;
interface BaseImagesLayoutContainerProps {
  baseImageCollectionRef: BaseImageCollection_BaseImagesFragment$key;
  searchText: string | null;
}
const BaseImagesLayoutContainer = ({
  baseImageCollectionRef,
  searchText,
}: BaseImagesLayoutContainerProps) => {
  const { data, loadNext, hasNext, isLoadingNext, refetch } =
    usePaginationFragment<
      BaseImages_PaginationQuery,
      BaseImageCollection_BaseImagesFragment$key
    >(BASE_IMAGES_FRAGMENT, baseImageCollectionRef);

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
                or: [
                  { version: { ilike: `%${text}%` } },
                  { url: { ilike: `%${text}%` } },
                  {
                    startingVersionRequirement: {
                      ilike: `%${text}%`,
                    },
                  },
                ],
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

  const loadNextBaseImages = useCallback(() => {
    if (hasNext && !isLoadingNext) {
      loadNext(RECORDS_TO_LOAD_NEXT);
    }
  }, [hasNext, isLoadingNext, loadNext]);

  const baseImagesRef = data?.baseImages;

  if (!baseImagesRef) {
    return null;
  }

  return (
    <BaseImagesTable
      baseImagesRef={baseImagesRef}
      baseImageCollectionId={data?.id}
      loading={isLoadingNext}
      onLoadMore={hasNext ? loadNextBaseImages : undefined}
    />
  );
};

type BaseImageCollectionContentProps = {
  baseImageCollection: NonNullable<
    BaseImageCollection_getBaseImageCollection_Query$data["baseImageCollection"]
  >;
};

const BaseImageCollectionContent = ({
  baseImageCollection,
}: BaseImageCollectionContentProps) => {
  const baseImageCollectionId = baseImageCollection.id;
  const navigate = useNavigate();
  const [showDeleteModal, setShowDeleteModal] = useState(false);
  const [errorFeedback, setErrorFeedback] = useState<React.ReactNode>(null);
  const [searchText, setSearchText] = useState<string | null>(null);

  const handleShowDeleteModal = useCallback(() => {
    setShowDeleteModal(true);
  }, [setShowDeleteModal]);

  const [deleteBaseImageCollection, isDeletingBaseImageCollection] =
    useMutation<BaseImageCollection_deleteBaseImageCollection_Mutation>(
      DELETE_BASE_IMAGE_COLLECTION_MUTATION,
    );

  const handleDeleteBaseImageCollection = useCallback(() => {
    deleteBaseImageCollection({
      variables: { baseImageCollectionId },
      onCompleted(data, errors) {
        if (!errors || errors.length === 0 || errors[0].code === "not_found") {
          return navigate({ route: Route.baseImageCollections });
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
            id="pages.BaseImageCollection.deletionErrorFeedback"
            defaultMessage="Could not delete the Base Image Collection, please try again."
          />,
        );
        setShowDeleteModal(false);
      },
      updater(store, data) {
        const baseImageCollectionId =
          data?.deleteBaseImageCollection?.result?.id;
        if (!baseImageCollectionId) {
          return;
        }

        const root = store.getRoot();

        const connection = ConnectionHandler.getConnection(
          root,
          "BaseImageCollectionsTable_baseImageCollections",
        );

        if (connection) {
          ConnectionHandler.deleteNode(connection, baseImageCollectionId);
        }

        store.delete(baseImageCollectionId);
      },
    });
  }, [deleteBaseImageCollection, baseImageCollectionId, navigate]);

  const [updateBaseImageCollection, isUpdatingBaseImageCollection] =
    useMutation<BaseImageCollection_updateBaseImageCollection_Mutation>(
      UPDATE_BASE_IMAGE_COLLECTION_MUTATION,
    );

  const handleUpdateBaseImageCollection = useCallback(
    (changes: BaseImageCollectionChanges) => {
      updateBaseImageCollection({
        variables: {
          baseImageCollectionId,
          input: changes,
          first: 10_000,
        },
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
              id="pages.BaseImageCollection.updateErrorFeedback"
              defaultMessage="Could not update the Base Image Collection, please try again."
            />,
          );
        },
      });
    },
    [updateBaseImageCollection, baseImageCollectionId],
  );

  return (
    <Page>
      <Page.Header title={baseImageCollection.name} />
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
          <UpdateBaseImageCollectionForm
            baseImageCollectionRef={baseImageCollection}
            onSubmit={handleUpdateBaseImageCollection}
            onDelete={handleShowDeleteModal}
            isLoading={isUpdatingBaseImageCollection}
          />
        </div>
        <hr className="bg-secondary border-2 border-top border-secondary" />
        <div className="d-flex justify-content-between align-items-center gap-2">
          <h3>
            <FormattedMessage
              id="pages.BaseImageCollection.baseImagesLabel"
              defaultMessage="Base Images"
            />
          </h3>
          <Button
            variant="secondary"
            as={Link}
            route={Route.baseImagesNew}
            params={{ baseImageCollectionId }}
          >
            <FormattedMessage
              id="pages.BaseImageCollection.createBaseImageButton"
              defaultMessage="Create Base Image"
            />
          </Button>
        </div>
        <SearchBox
          className="flex-grow-1 pb-2"
          value={searchText || ""}
          onChange={setSearchText}
        />
        <BaseImagesLayoutContainer
          baseImageCollectionRef={baseImageCollection}
          searchText={searchText}
        />
        {showDeleteModal && (
          <DeleteModal
            confirmText={baseImageCollection?.handle || ""}
            onCancel={() => setShowDeleteModal(false)}
            onConfirm={handleDeleteBaseImageCollection}
            isDeleting={isDeletingBaseImageCollection}
            title={
              <FormattedMessage
                id="pages.BaseImageCollection.deleteModal.title"
                defaultMessage="Delete Base Image Collection"
                description="Title for the confirmation modal to delete a Base Image Collection"
              />
            }
          >
            <p>
              <FormattedMessage
                id="pages.BaseImageCollection.deleteModal.description"
                defaultMessage="This action cannot be undone. This will permanently delete the Base Image Collection <bold>{baseImageCollection}</bold>."
                description="Description for the confirmation modal to delete a Base Image Collection"
                values={{
                  baseImageCollection: baseImageCollection.name,
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

type BaseImageCollectionWrapperProps = {
  getBaseImageCollectionQuery: PreloadedQuery<BaseImageCollection_getBaseImageCollection_Query>;
};

const BaseImageCollectionWrapper = ({
  getBaseImageCollectionQuery,
}: BaseImageCollectionWrapperProps) => {
  const { baseImageCollection } = usePreloadedQuery(
    GET_BASE_IMAGE_COLLECTION_QUERY,
    getBaseImageCollectionQuery,
  );

  if (!baseImageCollection) {
    return (
      <Result.NotFound
        title={
          <FormattedMessage
            id="pages.BaseImageCollection.baseImageCollectionNotFound.title"
            defaultMessage="Base Image Collection not found."
          />
        }
      >
        <Link route={Route.baseImageCollections}>
          <FormattedMessage
            id="pages.BaseImageCollection.baseImageCollectionNotFound.message"
            defaultMessage="Return to the Base Image Collection list."
          />
        </Link>
      </Result.NotFound>
    );
  }

  return (
    <BaseImageCollectionContent baseImageCollection={baseImageCollection} />
  );
};

const BaseImageCollectionPage = () => {
  const { baseImageCollectionId = "" } = useParams();

  const [getBaseImageCollectionQuery, getBaseImageCollection] =
    useQueryLoader<BaseImageCollection_getBaseImageCollection_Query>(
      GET_BASE_IMAGE_COLLECTION_QUERY,
    );

  const fetchBaseImageCollection = useCallback(
    () =>
      getBaseImageCollection(
        { baseImageCollectionId, first: RECORDS_TO_LOAD_FIRST },
        { fetchPolicy: "network-only" },
      ),
    [getBaseImageCollection, baseImageCollectionId],
  );

  useEffect(fetchBaseImageCollection, [fetchBaseImageCollection]);

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
        onReset={fetchBaseImageCollection}
      >
        {getBaseImageCollectionQuery && (
          <BaseImageCollectionWrapper
            getBaseImageCollectionQuery={getBaseImageCollectionQuery}
          />
        )}
      </ErrorBoundary>
    </Suspense>
  );
};

export default BaseImageCollectionPage;
