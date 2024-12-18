/*
  This file is part of Edgehog.

  Copyright 2024 SECO Mind Srl

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
import {
  FunctionComponent,
  ReactNode,
  Suspense,
  useCallback,
  useEffect,
  useState,
} from "react";
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

const { imageCredentials: imageCredentialsRoute } = Route;
const { Header, Main, LoadingError } = Page;
const { NotFound } = Result;

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

const ImageCredentialContent: FunctionComponent<
  ImageCredentialContentProps
> = ({
  imageCredential: { id: imageCredentialId, label },
  imageCredential,
}) => {
  const navigate = useNavigate();
  const [showDeleteModal, setShowDeleteModal] = useState(false);
  const [errorFeedback, setErrorFeedback] = useState<ReactNode>(null);

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
          return navigate({ route: imageCredentialsRoute });
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
            defaultMessage="Could not delete the image credentials, please try again."
          />,
        );
        setShowDeleteModal(false);
      },
    });
  }, [deleteImageCredential, imageCredentialId, navigate]);

  return (
    <Page>
      <Header title={label} />
      <Main>
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
                values={{
                  imageCredentials: imageCredential.label,
                  bold: (chunks) => <strong>{chunks}</strong>,
                }}
              />
            </p>
          </DeleteModal>
        )}
      </Main>
    </Page>
  );
};

interface ImageCredentialWrapperProps {
  imageCredentialQuery: PreloadedQuery<ImageCredential_imageCredential_Query>;
}

const ImageCredentialWrapper: FunctionComponent<
  ImageCredentialWrapperProps
> = ({ imageCredentialQuery }) => {
  const { imageCredentials } = usePreloadedQuery(
    IMAGE_CREDENTIAL_QUERY,
    imageCredentialQuery,
  );

  if (!imageCredentials) {
    return (
      <NotFound
        title={
          <FormattedMessage
            id="pages.ImageCredential.imageCredentialNotFound.title"
            defaultMessage="Image credentials not found."
          />
        }
      >
        <Link route={imageCredentialsRoute}>
          <FormattedMessage
            id="pages.ImageCredential.imageCredentialNotFound.message"
            defaultMessage="Return to the image credentials list."
          />
        </Link>
      </NotFound>
    );
  }

  return <ImageCredentialContent imageCredential={imageCredentials} />;
};

interface Props {}

const ImageCredentialPage: FunctionComponent<Props> = () => {
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
            <LoadingError onRetry={resetErrorBoundary} />
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
