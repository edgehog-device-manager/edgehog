// This file is part of Edgehog.
//
// Copyright 2023 - 2026 SECO Mind Srl
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

import { Suspense, useCallback, useEffect, useState } from "react";
import { useParams } from "react-router-dom";
import { FormattedMessage } from "react-intl";
import { ErrorBoundary } from "react-error-boundary";
import {
  graphql,
  useMutation,
  usePreloadedQuery,
  useQueryLoader,
} from "react-relay/hooks";
import type { PreloadedQuery } from "react-relay/hooks";

import type {
  BaseImage_getBaseImage_Query,
  BaseImage_getBaseImage_Query$data,
} from "@/api/__generated__/BaseImage_getBaseImage_Query.graphql";
import type { BaseImage_updateBaseImage_Mutation } from "@/api/__generated__/BaseImage_updateBaseImage_Mutation.graphql";
import type { BaseImage_deleteBaseImage_Mutation } from "@/api/__generated__/BaseImage_deleteBaseImage_Mutation.graphql";
import Alert from "@/components/Alert";
import Center from "@/components/Center";
import DeleteModal from "@/components/DeleteModal";
import Page from "@/components/Page";
import Result from "@/components/Result";
import Spinner from "@/components/Spinner";
import UpdateBaseImageForm from "@/forms/UpdateBaseImage";
import type { BaseImageChanges } from "@/forms/UpdateBaseImage";
import { Link, Route, useNavigate } from "@/Navigation";

const GET_BASE_IMAGE_QUERY = graphql`
  query BaseImage_getBaseImage_Query($baseImageId: ID!) {
    baseImage(id: $baseImageId) {
      id
      version
      baseImageCollection {
        id
      }
      ...UpdateBaseImage_BaseImageFragment
    }
    ...UpdateBaseImage_OptionsFragment
  }
`;

const UPDATE_BASE_IMAGE_MUTATION = graphql`
  mutation BaseImage_updateBaseImage_Mutation(
    $baseImageId: ID!
    $input: UpdateBaseImageInput!
  ) {
    updateBaseImage(id: $baseImageId, input: $input) {
      result {
        id
        version
        baseImageCollection {
          id
        }
        ...UpdateBaseImage_BaseImageFragment
      }
    }
  }
`;

const DELETE_BASE_IMAGE_MUTATION = graphql`
  mutation BaseImage_deleteBaseImage_Mutation($baseImageId: ID!) {
    deleteBaseImage(id: $baseImageId) {
      result {
        id
      }
      errors {
        message
      }
    }
  }
`;

type BaseImageContentProps = {
  baseImage: NonNullable<BaseImage_getBaseImage_Query$data["baseImage"]>;
  queryRef: BaseImage_getBaseImage_Query$data;
};

const BaseImageContent = ({ baseImage, queryRef }: BaseImageContentProps) => {
  const baseImageId = baseImage.id;
  const baseImageCollectionId = baseImage.baseImageCollection.id;
  const navigate = useNavigate();

  const [showDeleteModal, setShowDeleteModal] = useState(false);
  const [errorFeedback, setErrorFeedback] = useState<React.ReactNode>(null);

  const handleShowDeleteModal = useCallback(() => {
    setShowDeleteModal(true);
  }, [setShowDeleteModal]);

  const [deleteBaseImage, isDeletingBaseImage] =
    useMutation<BaseImage_deleteBaseImage_Mutation>(DELETE_BASE_IMAGE_MUTATION);

  const handleDeleteBaseImage = useCallback(() => {
    deleteBaseImage({
      variables: { baseImageId },
      onCompleted(_data, errors) {
        if (!errors || errors.length === 0 || errors[0].code === "not_found") {
          return navigate({
            route: Route.baseImageCollectionsEdit,
            params: { baseImageCollectionId },
          });
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
            id="pages.BaseImage.deletionErrorFeedback"
            defaultMessage="Could not delete the Base Image, please try again."
          />,
        );
        setShowDeleteModal(false);
      },
      updater(store, data) {
        const baseImageId = data?.deleteBaseImage?.result?.id;
        if (!baseImageId) {
          return;
        }

        store.delete(baseImageId);
        store
          .getRoot()
          .getLinkedRecord("baseImageCollection", { id: baseImageCollectionId })
          ?.invalidateRecord();
      },
    });
  }, [deleteBaseImage, baseImageId, baseImageCollectionId, navigate]);

  const [updateBaseImage, isUpdatingBaseImage] =
    useMutation<BaseImage_updateBaseImage_Mutation>(UPDATE_BASE_IMAGE_MUTATION);

  const handleUpdateBaseImage = useCallback(
    (baseImageChanges: BaseImageChanges) => {
      updateBaseImage({
        variables: { baseImageId, input: baseImageChanges },
        onCompleted(_data, errors) {
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
              id="pages.BaseImage.creationErrorFeedback"
              defaultMessage="Could not update the Base Image, please try again."
            />,
          );
        },
      });
    },
    [updateBaseImage, baseImageId],
  );

  return (
    <Page>
      <Page.Header
        title={
          <FormattedMessage
            id="pages.BaseImage.title"
            defaultMessage="Base Image"
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
        <UpdateBaseImageForm
          baseImageRef={baseImage}
          optionsRef={queryRef}
          onSubmit={handleUpdateBaseImage}
          onDelete={handleShowDeleteModal}
          isLoading={isUpdatingBaseImage}
        />
        {showDeleteModal && (
          <DeleteModal
            confirmText={baseImage.version}
            onCancel={() => setShowDeleteModal(false)}
            onConfirm={handleDeleteBaseImage}
            isDeleting={isDeletingBaseImage}
            title={
              <FormattedMessage
                id="pages.BaseImage.deleteModal.title"
                defaultMessage="Delete Base Image"
                description="Title for the confirmation modal to delete a Base Image"
              />
            }
          >
            <p>
              <FormattedMessage
                id="pages.BaseImage.deleteModal.description"
                defaultMessage="This action cannot be undone. This will permanently delete the Base Image version <bold>{baseImageVersion}</bold>."
                description="Description for the confirmation modal to delete a Base Image"
                values={{
                  baseImageVersion: baseImage.version,
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

type BaseImageWrapperProps = {
  getBaseImageQuery: PreloadedQuery<BaseImage_getBaseImage_Query>;
};

const BaseImageWrapper = ({ getBaseImageQuery }: BaseImageWrapperProps) => {
  const { baseImageCollectionId = "" } = useParams();

  const queryData = usePreloadedQuery(GET_BASE_IMAGE_QUERY, getBaseImageQuery);

  if (!queryData.baseImage) {
    return (
      <Result.NotFound
        title={
          <FormattedMessage
            id="pages.BaseImage.baseImageNotFound.title"
            defaultMessage="Base Image not found."
          />
        }
      >
        <Link
          route={Route.baseImageCollectionsEdit}
          params={{ baseImageCollectionId }}
        >
          <FormattedMessage
            id="pages.BaseImage.baseImageNotFound.message"
            defaultMessage="Return to the Base Image Collection."
          />
        </Link>
      </Result.NotFound>
    );
  }

  return (
    <BaseImageContent baseImage={queryData.baseImage} queryRef={queryData} />
  );
};

const BaseImagePage = () => {
  const { baseImageId = "" } = useParams();

  const [getBaseImageQuery, getBaseImage] =
    useQueryLoader<BaseImage_getBaseImage_Query>(GET_BASE_IMAGE_QUERY);

  const fetchBaseImage = useCallback(() => {
    getBaseImage({ baseImageId }, { fetchPolicy: "network-only" });
  }, [getBaseImage, baseImageId]);

  useEffect(fetchBaseImage, [fetchBaseImage]);

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
        onReset={fetchBaseImage}
      >
        {getBaseImageQuery && (
          <BaseImageWrapper getBaseImageQuery={getBaseImageQuery} />
        )}
      </ErrorBoundary>
    </Suspense>
  );
};

export default BaseImagePage;
