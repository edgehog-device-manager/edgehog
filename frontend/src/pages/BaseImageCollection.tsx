/*
  This file is part of Edgehog.

  Copyright 2023 SECO Mind Srl

  Licensed under the Apache License, Version 2.0 (the "License");
  you may not use this file except in compliance with the License.
  You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

  Unless required by applicable law or agreed to in writing, software
  distributed under the License is distributed on an "AS IS" BASIS,
  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
  See the License for the specific language governing permissions and
  limitations under the License.

  SPDX-License-Identifier: Apache-2.0
*/

import { Suspense, useCallback, useEffect, useState } from "react";
import { useParams } from "react-router-dom";
import { ErrorBoundary } from "react-error-boundary";
import graphql from "babel-plugin-relay/macro";
import {
  useMutation,
  usePreloadedQuery,
  useQueryLoader,
  PreloadedQuery,
} from "react-relay/hooks";
import { FormattedMessage } from "react-intl";
import _ from "lodash";

import type {
  BaseImageCollection_getBaseImageCollection_Query,
  BaseImageCollection_getBaseImageCollection_Query$data,
} from "api/__generated__/BaseImageCollection_getBaseImageCollection_Query.graphql";
import type { BaseImageCollection_updateBaseImageCollection_Mutation } from "api/__generated__/BaseImageCollection_updateBaseImageCollection_Mutation.graphql";
import type { BaseImageCollection_deleteBaseImageCollection_Mutation } from "api/__generated__/BaseImageCollection_deleteBaseImageCollection_Mutation.graphql";
import { Link, Route, useNavigate } from "Navigation";
import Alert from "components/Alert";
import BaseImagesTable from "components/BaseImagesTable";
import Button from "components/Button";
import Center from "components/Center";
import DeleteModal from "components/DeleteModal";
import Page from "components/Page";
import Result from "components/Result";
import Spinner from "components/Spinner";
import UpdateBaseImageCollectionForm from "forms/UpdateBaseImageCollection";
import type { BaseImageCollectionChanges } from "forms/UpdateBaseImageCollection";

const GET_BASE_IMAGE_COLLECTION_QUERY = graphql`
  query BaseImageCollection_getBaseImageCollection_Query($id: ID!) {
    baseImageCollection(id: $id) {
      id
      name
      handle
      systemModel {
        name
      }
      ...BaseImagesTable_BaseImagesFragment
    }
  }
`;

const UPDATE_BASE_IMAGE_COLLECTION_MUTATION = graphql`
  mutation BaseImageCollection_updateBaseImageCollection_Mutation(
    $input: UpdateBaseImageCollectionInput!
  ) {
    updateBaseImageCollection(input: $input) {
      baseImageCollection {
        id
        name
        handle
      }
    }
  }
`;

const DELETE_BASE_IMAGE_COLLECTION_MUTATION = graphql`
  mutation BaseImageCollection_deleteBaseImageCollection_Mutation(
    $input: DeleteBaseImageCollectionInput!
  ) {
    deleteBaseImageCollection(input: $input) {
      baseImageCollection {
        id
      }
    }
  }
`;

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

  const handleShowDeleteModal = useCallback(() => {
    setShowDeleteModal(true);
  }, [setShowDeleteModal]);

  const [deleteBaseImageCollection, isDeletingBaseImageCollection] =
    useMutation<BaseImageCollection_deleteBaseImageCollection_Mutation>(
      DELETE_BASE_IMAGE_COLLECTION_MUTATION
    );

  const handleDeleteBaseImageCollection = useCallback(() => {
    const input = {
      baseImageCollectionId,
    };
    deleteBaseImageCollection({
      variables: { input },
      onCompleted(data, errors) {
        if (errors) {
          const errorFeedback = errors
            .map((error) => error.message)
            .join(". \n");
          setErrorFeedback(errorFeedback);
          return setShowDeleteModal(false);
        }
        navigate({ route: Route.baseImageCollections });
      },
      onError() {
        setErrorFeedback(
          <FormattedMessage
            id="pages.BaseImageCollection.deletionErrorFeedback"
            defaultMessage="Could not delete the Base Image Collection, please try again."
          />
        );
        setShowDeleteModal(false);
      },
      updater(store) {
        const baseImageCollection = store
          .getRootField("deleteBaseImageCollection")
          .getLinkedRecord("baseImageCollection");
        const baseImageCollectionId = baseImageCollection.getDataID();
        const root = store.getRoot();

        const baseImageCollections = root.getLinkedRecords(
          "baseImageCollections"
        );
        if (baseImageCollections) {
          root.setLinkedRecords(
            baseImageCollections.filter(
              (baseImageCollection) =>
                baseImageCollection.getDataID() !== baseImageCollectionId
            ),
            "baseImageCollections"
          );
        }

        store.delete(baseImageCollectionId);
      },
    });
  }, [deleteBaseImageCollection, baseImageCollectionId, navigate]);

  const [updateBaseImageCollection, isUpdatingBaseImageCollection] =
    useMutation<BaseImageCollection_updateBaseImageCollection_Mutation>(
      UPDATE_BASE_IMAGE_COLLECTION_MUTATION
    );

  const handleUpdateBaseImageCollection = useCallback(
    (baseImageCollection: BaseImageCollectionChanges) => {
      const input = {
        baseImageCollectionId,
        ...baseImageCollection,
      };
      updateBaseImageCollection({
        variables: { input },
        onCompleted(data, errors) {
          if (errors) {
            const errorFeedback = errors
              .map((error) => error.message)
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
            />
          );
        },
      });
    },
    [updateBaseImageCollection, baseImageCollectionId]
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
            initialData={_.pick(baseImageCollection, [
              "name",
              "handle",
              "systemModel",
            ])}
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
        <BaseImagesTable
          baseImageCollectionRef={baseImageCollection}
          hideSearch
        />
        {showDeleteModal && (
          <DeleteModal
            confirmText={baseImageCollection.handle}
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
    getBaseImageCollectionQuery
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
      GET_BASE_IMAGE_COLLECTION_QUERY
    );

  const fetchBaseImageCollection = useCallback(() => {
    getBaseImageCollection(
      { id: baseImageCollectionId },
      { fetchPolicy: "network-only" }
    );
  }, [getBaseImageCollection, baseImageCollectionId]);

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
