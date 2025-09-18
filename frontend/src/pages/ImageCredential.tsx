/*
  This file is part of Edgehog.

  Copyright 2024-2025 SECO Mind Srl

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

import { ReactNode, Suspense, useCallback, useEffect, useState } from "react";
import { Alert } from "react-bootstrap";
import { ErrorBoundary } from "react-error-boundary";
import { FormattedMessage } from "react-intl";
import {
  graphql,
  PreloadedQuery,
  useMutation,
  usePreloadedQuery,
  useQueryLoader,
} from "react-relay";
import { useParams } from "react-router-dom";

import type { ImageCredential_deleteImageCredentialDelete_Mutation } from "api/__generated__/ImageCredential_deleteImageCredentialDelete_Mutation.graphql";
import {
  ImageCredential_imageCredential_Query,
  ImageCredential_imageCredential_Query$data,
} from "api/__generated__/ImageCredential_imageCredential_Query.graphql";

import Center from "components/Center";
import DeleteModal from "components/DeleteModal";
import Page from "components/Page";
import Result from "components/Result";
import Spinner from "components/Spinner";
import UpdateImageCredentialForm from "forms/UpdateImageCredential";
import { Link, Route, useNavigate } from "Navigation";

const IMAGE_CREDENTIAL_QUERY = graphql`
  query ImageCredential_imageCredential_Query($imageCredentialId: ID!) {
    imageCredentials(id: $imageCredentialId) {
      id
      label
      ...UpdateImageCredential_imageCredential_Fragment
    }
  }
`;

const DELETE_IMAGE_CREDENTIAL_MUTATION = graphql`
  mutation ImageCredential_deleteImageCredentialDelete_Mutation(
    $imageCredentialId: ID!
  ) {
    deleteImageCredentials(id: $imageCredentialId) {
      result {
        id
      }
    }
  }
`;

interface ImageCredentialContentProps {
  imageCredential: NonNullable<
    ImageCredential_imageCredential_Query$data["imageCredentials"]
  >;
}

const ImageCredentialContent = ({
  imageCredential,
}: ImageCredentialContentProps) => {
  const navigate = useNavigate();
  const [showDeleteModal, setShowDeleteModal] = useState(false);
  const [errorFeedback, setErrorFeedback] = useState<ReactNode>(null);

  const { imageCredentialId = "" } = useParams();

  const handleShowDeleteModal = useCallback(() => {
    setShowDeleteModal(true);
  }, [setShowDeleteModal]);

  const [deleteImageCredential, isDeletingImageCredential] =
    useMutation<ImageCredential_deleteImageCredentialDelete_Mutation>(
      DELETE_IMAGE_CREDENTIAL_MUTATION,
    );

  const handleDeleteImageCredential = useCallback(() => {
    deleteImageCredential({
      variables: { imageCredentialId },
      onCompleted(_data, errors) {
        if (!errors || errors.length === 0 || errors[0].code === "not_found") {
          return navigate({ route: Route.imageCredentials });
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
            id="pages.ImageCredential.deletionErrorFeedback"
            defaultMessage="Could not delete the Image Credentials, please try again."
          />,
        );
        setShowDeleteModal(false);
      },
    });
  }, [deleteImageCredential, imageCredentialId, navigate]);

  return (
    <Page>
      <Page.Header title={imageCredential.label} />
      <Page.Main>
        <Alert
          show={!!errorFeedback}
          variant="danger"
          onClose={() => setErrorFeedback(null)}
          dismissible
        >
          {errorFeedback}
        </Alert>
        <UpdateImageCredentialForm
          imageCredentialRef={imageCredential}
          onDelete={handleShowDeleteModal}
        />
        {showDeleteModal && (
          <DeleteModal
            confirmText={imageCredential.label}
            onCancel={() => setShowDeleteModal(false)}
            onConfirm={handleDeleteImageCredential}
            isDeleting={isDeletingImageCredential}
            title={
              <FormattedMessage
                id="pages.ImageCredential.deleteModal.title"
                defaultMessage="Delete Image Credentials"
              />
            }
          >
            <p>
              <FormattedMessage
                id="pages.ImageCredential.deleteModal.description"
                defaultMessage="This action cannot be undone. This will permanently delete the Image Credentials <bold>{imageCredentials}</bold>."
                values={{
                  imageCredentials: imageCredential.label,
                  bold: (chunks) => <strong>{chunks}</strong>,
                }}
              />
            </p>
          </DeleteModal>
        )}
      </Page.Main>
    </Page>
  );
};

interface ImageCredentialWrapperProps {
  imageCredentialQuery: PreloadedQuery<ImageCredential_imageCredential_Query>;
}

const ImageCredentialWrapper = ({
  imageCredentialQuery,
}: ImageCredentialWrapperProps) => {
  const { imageCredentials } = usePreloadedQuery(
    IMAGE_CREDENTIAL_QUERY,
    imageCredentialQuery,
  );

  if (!imageCredentials) {
    return (
      <Result.NotFound
        title={
          <FormattedMessage
            id="pages.ImageCredential.imageCredentialNotFound.title"
            defaultMessage="Image Credentials not found."
          />
        }
      >
        <Link route={Route.imageCredentials}>
          <FormattedMessage
            id="pages.ImageCredential.imageCredentialNotFound.message"
            defaultMessage="Return to the Image Credentials list."
          />
        </Link>
      </Result.NotFound>
    );
  }

  return <ImageCredentialContent imageCredential={imageCredentials} />;
};

const ImageCredentialPage = () => {
  const { imageCredentialId = "" } = useParams();

  const [imageCredentialQuery, getImageCredential] =
    useQueryLoader<ImageCredential_imageCredential_Query>(
      IMAGE_CREDENTIAL_QUERY,
    );

  const fetchImageCredential = useCallback(() => {
    getImageCredential({ imageCredentialId }, { fetchPolicy: "network-only" });
  }, [getImageCredential, imageCredentialId]);

  useEffect(fetchImageCredential, [fetchImageCredential]);

  return (
    <Suspense
      fallback={
        <Center data-testid="page-loading">
          <Spinner />
        </Center>
      }
    >
      <ErrorBoundary
        FallbackComponent={({ resetErrorBoundary }) => (
          <Center data-testid="page-error">
            <Page.LoadingError onRetry={resetErrorBoundary} />
          </Center>
        )}
        onReset={fetchImageCredential}
      >
        {imageCredentialQuery && (
          <ImageCredentialWrapper imageCredentialQuery={imageCredentialQuery} />
        )}
      </ErrorBoundary>
    </Suspense>
  );
};

export default ImageCredentialPage;
